import promptAction from '@ohos.promptAction';
import { MuseumVoiceService } from '../common/voice/MuseumVoiceService';
import picker from '@ohos.file.picker';
import common from '@ohos.app.ability.common';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import router from '@ohos.router';
import { cameraPicker } from '@kit.CameraKit';
import { camera } from '@kit.CameraKit';
import fs from '@ohos.file.fs';
import http from '@ohos.net.http';
import util from '@ohos.util';
// 文物条目类型（与后端约定）
interface ArtifactItem {
  id: number;
  name: string;
  era: string;
  image: string;
  similarity: number;
}

// 后端响应结构
interface SearchResponse {
  code: number;
  message?: string;
  data: ArtifactItem[];
}

// 路由参数
interface RouterParams {
  image: string;
  results: string;
}

interface RouterOptions {
  url: string;
  params: RouterParams;
}

@Entry
@Component
export struct DiscoverPage {
  @State searchInput: string = '';
  @State voiceText: string = '';
  @State selectedImage: string = '';
  @State isSearching: boolean = false;

  private readonly SEARCH_API_URL: string = 'http://192.168.1.100:8080/api/image-search'; // 替换为实际地址

  async aboutToAppear() {}

  // ==================== 权限申请 ====================
  async requestPermissions(): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const permissions: Array<Permissions> = ['ohos.permission.CAMERA', 'ohos.permission.READ_MEDIA'];
    const context = getContext(this) as common.UIAbilityContext;
    try {
      const result = await atManager.requestPermissionsFromUser(context, permissions);
      const isAllGranted = result.authResults.every(item => item === 0);
      if (!isAllGranted) {
        promptAction.showToast({ message: '权限被拒绝，部分功能无法使用' });
      }
      return isAllGranted;
    } catch (err) {
      promptAction.showToast({ message: '权限申请失败' });
      return false;
    }
  }

  // ==================== 拍照搜索 ====================
  async openCamera() {
    if (this.isSearching) {
      promptAction.showToast({ message: '正在搜索中，请稍后' });
      return;
    }
    if (!await this.requestPermissions()) return;

    try {
      const pickerProfile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
      };
      const pickerResult: cameraPicker.PickerResult = await cameraPicker.pick(
        getContext(this),
        [cameraPicker.PickerMediaType.PHOTO],
        pickerProfile
      );
      if (pickerResult.resultCode === 0 && pickerResult.resultUri) {
        this.selectedImage = pickerResult.resultUri;
        await this.uploadAndSearchViaBase64(this.selectedImage);
      } else {
        promptAction.showToast({ message: '未获取到照片' });
      }
    } catch (err) {
      console.error(`拍照失败: ${err}`);
      promptAction.showToast({ message: '打开相机失败' });
    }
  }

  // ==================== 相册选择图片 ====================
  async openAlbum() {
    if (this.isSearching) {
      promptAction.showToast({ message: '正在搜索中，请稍后' });
      return;
    }
    if (!await this.requestPermissions()) return;

    try {
      const photoPicker = new picker.PhotoViewPicker();
      const result: picker.PhotoSelectResult = await photoPicker.select({
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length > 0) {
        this.selectedImage = result.photoUris[0];
        await this.uploadAndSearchViaBase64(this.selectedImage);
      }
    } catch (err) {
      promptAction.showToast({ message: '选择图片失败' });
    }
  }

  // ==================== 辅助函数：ArrayBuffer → Base64 ====================
  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    // 创建一个 Base64Helper 实例
    const base64Helper = new util.Base64Helper();
    // 将 ArrayBuffer 转为 Uint8Array
    const uint8Array = new Uint8Array(buffer);
    // 使用原生方法编码，性能更好，也符合 ArkTS 规范
    return base64Helper.encodeToStringSync(uint8Array);
  }

  // ==================== 图片上传并检索 ====================
  async uploadAndSearchViaBase64(imageUri: string) {
    this.isSearching = true;
    promptAction.showToast({ message: '处理图片中...' });

    try {
      const file = fs.openSync(imageUri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);

      const base64Image = this.arrayBufferToBase64(buffer);

      const httpRequest = http.createHttp();
      const response = await httpRequest.request(this.SEARCH_API_URL, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify({ image: base64Image, filename: 'upload.jpg' }),
        connectTimeout: 30000,
        readTimeout: 30000
      });
      httpRequest.destroy();

      if (response.responseCode === 200) {
        // 明确指定 JSON 解析结果的类型
        const result: SearchResponse = JSON.parse(response.result as string);
        if (result.code === 0 && result.data) {
          const sortedResults = result.data.sort((a, b) => b.similarity - a.similarity);
          this.navigateToResultPage(imageUri, sortedResults);
        } else {
          promptAction.showToast({ message: result.message || '未找到相似文物' });
        }
      } else {
        promptAction.showToast({ message: `请求失败: ${response.responseCode}` });
      }
    } catch (err) {
      console.error(`图片上传检索失败: `,JSON.stringify(err));
      promptAction.showToast({ message: '网络错误，请检查网络后重试' });
    } finally {
      this.isSearching = false;
    }
  }

  private navigateToResultPage(userImageUri: string, results: ArtifactItem[]) {
    const routerOptions: RouterOptions = {
      url: 'pages/ImageSearchResultPage',
      params: {
        image: userImageUri,
        results: JSON.stringify(results)
      }
    };
    router.pushUrl(routerOptions);
  }

  // ==================== UI 构建 ====================
  build() {
    Column() {
      Column({ space: 4 }) {
        Text('发现')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827');
      }
      .margin({ top: 20, bottom: 16 });

      this.voiceSearchCard();
      this.imageSearchCard();
      Blank();
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F4F6')
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  voiceSearchCard() {
    Column({ space: 16 }) {
      Row() {
        Text('语音搜索')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827');
        Button('🎧 语音提示')
          .width(92)
          .height(32)
          .fontSize(12)
          .backgroundColor('#E5E7EB')
          .fontColor('#374151')
          .borderRadius(16)
          .margin({ left: 12 })
          .onClick(() => {
            MuseumVoiceService.speak('欢迎使用掌上博物馆语音搜索，请说出你想查找的文物名称、年代、类型或博物馆名称。');
          });
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Text('支持关键词：青花、唐三彩、玉琮、青铜、大英博物馆')
        .fontSize(13)
        .fontColor('#9CA3AF')
        .alignSelf(ItemAlign.Start);

      TextInput({ placeholder: '请输入或说出文物名称、年代、博物馆...' })
        .width('100%')
        .height(50)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#D1D5DB' })
        .borderRadius(12)
        .padding({ left: 16 })
        .onChange((value: string) => this.searchInput = value);

      Button('🎙️ 开始语音搜索')
        .width('100%')
        .height(50)
        .backgroundColor('#007AFF')
        .borderRadius(12)
        .onClick(() => {
          if (!this.searchInput.trim()) {
            promptAction.showToast({ message: '请输入或说出搜索内容' });
            return;
          }
          this.voiceText = this.searchInput;
          MuseumVoiceService.handleVoiceSearch(this.voiceText);
        });

      if (this.voiceText) {
        Text(`✅ 识别结果：${this.voiceText}`)
          .fontSize(15)
          .fontColor('#059669')
          .alignSelf(ItemAlign.Start)
          .margin({ top: 4 });
      }
    }
    .width('92%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .shadow({ radius: 6, color: '#0000000A', offsetX: 0, offsetY: 2 });
  }

  @Builder
  imageSearchCard() {
    Column({ space: 16 }) {
      Text('以图搜图')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111827')
        .alignSelf(ItemAlign.Start);

      Button('📷 拍照搜索文物')
        .width('100%')
        .height(54)
        .backgroundColor('#F97316')
        .borderRadius(12)
        .enabled(!this.isSearching)
        .onClick(async () => await this.openCamera());

      Button('🖼️ 从相册选择图片')
        .width('100%')
        .height(54)
        .backgroundColor('#8B5CF6')
        .borderRadius(12)
        .enabled(!this.isSearching)
        .onClick(async () => await this.openAlbum());

      if (this.isSearching) {
        Text('⏳ 正在识别文物，请稍候...')
          .fontSize(14)
          .fontColor('#059669')
          .alignSelf(ItemAlign.Start);
      } else if (this.selectedImage && !this.isSearching) {
        Text('✅ 已选择图片，识别完成')
          .fontSize(14)
          .fontColor('#059669')
          .alignSelf(ItemAlign.Start);
      }
    }
    .width('92%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .margin({ top: 16 })
    .shadow({ radius: 6, color: '#0000000A', offsetX: 0, offsetY: 2 });
  }
}
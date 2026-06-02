// entry/src/main/ets/pages/DiscoverPage.ets

import promptAction from '@ohos.promptAction';
import { MuseumVoiceService } from '../common/voice/MuseumVoiceService';
import picker from '@ohos.file.picker';
import common from '@ohos.app.ability.common';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import router from '@ohos.router';
import { cameraPicker, camera } from '@kit.CameraKit';
import { SearchService } from '../common/services/SearchService';
import type { SearchResponse, SearchResultItem } from '../common/models/SearchModels';

/**
 * 传给结果页的单条搜索结果（可 JSON 序列化）
 */
interface SearchResultDTO {
  objectId: string;
  title: string;
  period: string;
  type: string;
  material: string;
  imageUrl: string;
  similarity: number;
}

@Entry
@Component
export struct DiscoverPage {
  // 搜索输入
  @State searchInput: string = '';
  // 语音识别文本
  @State voiceText: string = '';
  // 选中的图片
  @State selectedImage: string = '';
  // 是否正在搜索（加载状态）
  @State isSearching: boolean = false;

  /**
   * 申请拍照 / 相册权限
   */
  async requestImagePermissions(): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const permissions: Array<Permissions> = [
      'ohos.permission.CAMERA',
      'ohos.permission.READ_MEDIA'
    ];
    const context = getContext(this) as common.UIAbilityContext;
    try {
      const result = await atManager.requestPermissionsFromUser(context, permissions);
      const isAllGranted = result.authResults.every((item: number) => item === 0);
      if (!isAllGranted) {
        promptAction.showToast({ message: '拍照或相册权限被拒绝' });
      }
      return isAllGranted;
    } catch (err) {
      promptAction.showToast({ message: '权限申请失败' });
      return false;
    }
  }

  /**
   * 申请麦克风权限，用于语音搜索
   */
  async requestMicrophonePermission(): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    const permissions: Array<Permissions> = [
      'ohos.permission.MICROPHONE'
    ];
    const context = getContext(this) as common.UIAbilityContext;
    try {
      const result = await atManager.requestPermissionsFromUser(context, permissions);
      const isGranted = result.authResults.every((item: number) => item === 0);
      if (!isGranted) {
        promptAction.showToast({ message: '麦克风权限被拒绝，无法使用语音搜索' });
      }
      return isGranted;
    } catch (err) {
      promptAction.showToast({ message: '麦克风权限申请失败' });
      return false;
    }
  }

  /**
   * 拍照搜索：调系统相机拍一张，拿到 uri 后走真实搜索流程
   */
  async openCamera(): Promise<void> {
    if (!await this.requestImagePermissions()) {
      return;
    }
    try {
      const context = getContext(this) as common.Context;
      const result = await cameraPicker.pick(
        context,
        [cameraPicker.PickerMediaType.PHOTO],
        { cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK }
      );
      if (result && result.resultCode === 0 && result.resultUri) {
        this.selectedImage = result.resultUri;
        await this.runImageSearch(result.resultUri);
      } else {
        promptAction.showToast({ message: '已取消拍照' });
      }
    } catch (err) {
      promptAction.showToast({ message: '打开相机失败' });
    }
  }

  /**
   * 相册选择图片：拿到 uri 后走真实搜索流程
   */
  async openAlbum(): Promise<void> {
    if (!await this.requestImagePermissions()) {
      return;
    }
    try {
      const photoPicker = new picker.PhotoViewPicker();
      const result = await photoPicker.select({
        MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length > 0) {
        this.selectedImage = result.photoUris[0];
        await this.runImageSearch(result.photoUris[0]);
      }
    } catch (err) {
      promptAction.showToast({ message: '选择图片失败' });
    }
  }

  /**
   * 以图搜图流程（调用后端 API）：
   * 1. 调用 SearchService.searchByImage 上传图片
   * 2. 根据相似度阈值过滤结果（0.85）
   * 3. 转换为 DTO 并跳转结果页（即使为空也跳转）
   */
  async runImageSearch(uri: string): Promise<void> {
    if (!uri || this.isSearching) {
      return;
    }
    this.isSearching = true;
    try {
      // 从 uri 中提取文件名（用于服务端表单字段）
      const fileName = uri.split('/').pop() || 'image.jpg';
      const TOP_K = 5;
      const THRESHOLD = 0.85;

      const response: SearchResponse = await SearchService.searchByImage(
        uri,
        fileName,
        TOP_K,
        THRESHOLD
      );

      // 后端已根据 threshold 过滤，但前端再确保一次
      const results: SearchResultItem[] = (response.data?.results || [])
        .filter(item => item.similarity >= THRESHOLD);

      const dtoList: SearchResultDTO[] = results.map((item: SearchResultItem): SearchResultDTO => ({
        objectId: item.objectId,
        title: item.title,
        period: item.period,
        type: item.type,
        material: item.material,
        imageUrl: item.imageUrl,
        similarity: item.similarity
      }));

      router.pushUrl({
        url: 'pages/ImageSearchResultPage',
        params: {
          image: uri,
          results: JSON.stringify(dtoList)
        }
      });
    } catch (err) {
      console.error('搜索失败', JSON.stringify(err));
      promptAction.showToast({ message: '搜索失败：' + (err.message || '未知错误') });
    } finally {
      this.isSearching = false;
    }
  }

  build() {
    Column() {
      Column({ space: 4 }) {
        Text('发现')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3A3A3A')
      }
      .margin({ top: 20, bottom: 16 })

      // 语音搜索卡片
      this.voiceSearchCard()

      // 以图搜图卡片
      this.imageSearchCard()

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F0E8')
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * 语音搜索模块（保持不变）
   */
  @Builder
  voiceSearchCard() {
    Column({ space: 16 }) {
      Row() {
        Text('🎙️ 语音搜索')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3A3A3A')
        Button('语音提示')
          .width(92)
          .height(32)
          .fontSize(12)
          .backgroundColor('#F2EDE8')
          .fontColor('#8B7355')
          .borderRadius(16)
          .margin({ left: 12 })
          .onClick(() => {
            MuseumVoiceService.speak(
              '欢迎使用掌上博物馆语音搜索，请说出你想查找的文物名称、年代、类型或博物馆名称。'
            );
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text('支持关键词：青花、唐三彩、玉琮、青铜、大英博物馆')
        .fontSize(13)
        .fontColor('#8B7355')
        .alignSelf(ItemAlign.Start)

      TextInput({ placeholder: '请输入或说出文物名称、年代、博物馆...' })
        .width('100%')
        .height(50)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#E0D5C6' })
        .borderRadius(12)
        .fontColor('#3A3A3A')
        .placeholderColor('#999999')
        .padding({ left: 16 })
        .onChange((value: string) => {
          this.searchInput = value;
        })

      Button('文字搜索')
        .width('100%')
        .height(50)
        .fontSize(16)
        .backgroundColor('#C76B5A')
        .fontColor(Color.White)
        .borderRadius(12)
        .onClick(() => {
          if (!this.searchInput.trim()) {
            promptAction.showToast({ message: '请输入搜索内容' });
            return;
          }
          this.voiceText = this.searchInput;
          MuseumVoiceService.handleVoiceSearch(this.searchInput);
        })

      Button('开始语音搜索')
        .width('100%')
        .height(50)
        .fontSize(16)
        .backgroundColor('#A68B6A')
        .fontColor(Color.White)
        .borderRadius(12)
        .onClick(async () => {
          const hasPermission = await this.requestMicrophonePermission();
          if (!hasPermission) {
            return;
          }
          promptAction.showToast({ message: '请说出文物关键词' });
          MuseumVoiceService.startVoiceSearch((text: string) => {
            this.voiceText = text;
            this.searchInput = text;
          });
        })

      Button('结束语音识别')
        .width('100%')
        .height(50)
        .fontSize(16)
        .backgroundColor('#E0D5C6')
        .fontColor('#8B7355')
        .borderRadius(12)
        .onClick(() => {
          MuseumVoiceService.finishVoiceSearch();
        })

      if (this.voiceText) {
        Text(`识别 / 搜索结果：${this.voiceText}`)
          .fontSize(15)
          .fontColor('#C05040')
          .alignSelf(ItemAlign.Start)
          .margin({ top: 4 })
      }
    }
    .width('92%')
    .padding(20)
    .backgroundColor('#F2EDE8')
    .borderRadius(18)
    .shadow({
      radius: 6,
      color: '#18000000',
      offsetX: 0,
      offsetY: 2
    })
  }

  /**
   * 以图搜图模块（已修正）
   */
  @Builder
  imageSearchCard() {
    Column({ space: 16 }) {
      Text('📷 以图搜图')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')
        .alignSelf(ItemAlign.Start)

      Button(this.isSearching ? '搜索中...' : '拍照搜索文物')
        .width('100%')
        .height(54)
        .fontSize(16)
        .backgroundColor('#C76B5A')
        .fontColor(Color.White)
        .borderRadius(12)
        .enabled(!this.isSearching)
        .onClick(async () => {
          await this.openCamera();
        })

      Button(this.isSearching ? '搜索中...' : '从相册选择图片')
        .width('100%')
        .height(54)
        .fontSize(16)
        .backgroundColor('#A68B6A')
        .fontColor(Color.White)
        .borderRadius(12)
        .enabled(!this.isSearching)
        .onClick(async () => {
          await this.openAlbum();
        })

      if (this.selectedImage) {
        Text('已选择图片')
          .fontSize(14)
          .fontColor('#C05040')
          .alignSelf(ItemAlign.Start)
      }
    }
    .width('92%')
    .padding(20)
    .backgroundColor('#F2EDE8')
    .borderRadius(18)
    .margin({ top: 16 })
    .shadow({
      radius: 6,
      color: '#18000000',
      offsetX: 0,
      offsetY: 2
    })
  }
}
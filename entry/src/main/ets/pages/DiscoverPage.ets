import promptAction from '@ohos.promptAction';
import { MuseumVoiceService } from '../common/voice/MuseumVoiceService';
import picker from '@ohos.file.picker';
import common from '@ohos.app.ability.common';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import router from '@ohos.router';
import { cameraPicker, camera } from '@kit.CameraKit';
import { ImageSearchService } from '../common/services/ImageSearchService';
import type { SearchResult } from '../common/services/ImageSearchService';
import { createDeviceImageDecoder } from '../common/services/ImageDecoder';
import { createMockArtifactSource } from '../common/services/ArtifactRepository';

/**
 * 传给结果页的单条搜索结果（可 JSON 序列化）。
 * objectId = 文物 id，点击结果跳详情时用它。
 */
interface SearchResultDTO {
  objectId: string;
  title: string;
  period: string;
  type: string;
  material: string;
  imageUrl: string;
  similarity: number; // 0~1 的余弦相似度
}

/**
 * 全局共享的搜索服务（建库一次后常驻内存，避免每次搜索重算全库）。
 * 注入真机解码器 + mock 数据源；后端就绪后把 source 换成 createHttpArtifactSource() 即可。
 */
let sharedSearchService: ImageSearchService | null = null;

function getSearchService(context: common.UIAbilityContext): ImageSearchService {
  if (!sharedSearchService) {
    sharedSearchService = new ImageSearchService({
      decode: createDeviceImageDecoder(context),
      source: createMockArtifactSource()
      // 切真实后端：source: createHttpArtifactSource()  （并把 HttpApi 的 BASE_URL 指向新后端）
    });
  }
  return sharedSearchService;
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

  // 是否正在搜索（建库/提特征期间禁用按钮、给提示）
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
   * 拍照搜索：调系统相机拍一张，拿到 uri 后走真实搜索流程（真机演示）
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
      // resultCode 为 0 表示拍照成功
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
   * 真实以图搜图流程：
   * 1) 确保向量库已建（首次进入建一次，常驻内存）
   * 2) 对查询图提特征
   * 3) 余弦检索 + 阈值过滤 + 降序 topK
   * 4) 带结果跳结果页（即使为空也跳，由结果页展示「搜不到」）
   */
  async runImageSearch(uri: string): Promise<void> {
    if (!uri || this.isSearching) {
      return;
    }
    this.isSearching = true;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const service = getSearchService(context);

      // 首次搜索前建库（对每件文物的 rawfile 图提特征）
      if (service.librarySize === 0) {
        promptAction.showToast({ message: '正在建立文物特征库…' });
        await service.initArtifactVectors();
      }

      // 查询图提特征 -> 检索
      const queryVector = await service.extractImageFeature(uri);
      const results: SearchResult[] = service.searchSimilarArtifacts(queryVector);

      const dtoList: SearchResultDTO[] = results.map((r: SearchResult): SearchResultDTO => {
        return {
          objectId: r.artifact.id,
          title: r.artifact.title,
          period: r.artifact.period,
          type: r.artifact.type,
          material: r.artifact.material,
          imageUrl: r.artifact.imageUrl,
          similarity: r.similarity
        };
      });

      router.pushUrl({
        url: 'pages/ImageSearchResultPage',
        params: {
          image: uri,
          results: JSON.stringify(dtoList)
        }
      });
    } catch (err) {
      promptAction.showToast({ message: '搜索失败：' + JSON.stringify(err) });
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
   * 语音搜索模块
   */
  @Builder
  voiceSearchCard() {
    Column({ space: 16 }) {
      Row() {
        Text('🎙️  语音搜索')          // 增加图标
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
        .backgroundColor('#C76B5A')           // 柔化敦煌红
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
        .backgroundColor('#A68B6A')           // 浅大地色
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
   * 以图搜图模块
   */
  @Builder
  imageSearchCard() {
    Column({ space: 16 }) {
      Text('📷  以图搜图')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')
        .alignSelf(ItemAlign.Start)

      Button(this.isSearching ? '搜索中…' : '拍照搜索文物')
        .width('100%')
        .height(54)
        .fontSize(16)
        .backgroundColor('#C76B5A')           // 与文字搜索同色，统一柔和红
        .fontColor(Color.White)
        .borderRadius(12)
        .enabled(!this.isSearching)
        .onClick(async () => {
          await this.openCamera();
        })

      Button(this.isSearching ? '搜索中…' : '从相册选择图片')
        .width('100%')
        .height(54)
        .fontSize(16)
        .backgroundColor('#A68B6A')           // 浅褐
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

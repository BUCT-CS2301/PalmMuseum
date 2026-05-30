import promptAction from '@ohos.promptAction';
import { MuseumVoiceService } from '../common/voice/MuseumVoiceService';
import picker from '@ohos.file.picker';
import common from '@ohos.app.ability.common';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import router from '@ohos.router';

/**
 * 文物条目类型定义
 */
interface ArtifactItem {
  id: number;
  name: string;
  era: string;
  image: string;
  similarity: number;
}

/**
 * 路由参数类型
 */
interface RouterParams {
  image: string;
  results: string;
}

/**
 * 路由配置类型
 */
interface RouterOptions {
  url: string;
  params: RouterParams;
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

  // 模拟文物数据
  private readonly mockArtifacts: ArtifactItem[] = [
    {
      id: 1,
      name: '青花瓷瓶',
      era: '明代',
      image: 'https://img2.baidu.com/it/u=3871232861,3188699794&fm=253&fmt=auto',
      similarity: 0
    },
    {
      id: 2,
      name: '唐三彩马',
      era: '唐代',
      image: 'https://img2.baidu.com/it/u=3103356365,1527751139&fm=253&fmt=auto',
      similarity: 0
    },
    {
      id: 3,
      name: '玉琮',
      era: '良渚文化',
      image: 'https://img1.baidu.com/it/u=1679148656,2910535149&fm=253&fmt=auto',
      similarity: 0
    },
    {
      id: 4,
      name: '青铜鼎',
      era: '商代',
      image: 'https://img0.baidu.com/it/u=4119932281,1072797093&fm=253&fmt=auto',
      similarity: 0
    }
  ];

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
   * 拍照搜索
   */
  async openCamera(): Promise<void> {
    if (!await this.requestImagePermissions()) {
      return;
    }

    try {
      this.selectedImage = 'camera_mock_image';
      promptAction.showToast({ message: '拍照成功' });
      this.startImageSearch();
    } catch (err) {
      promptAction.showToast({ message: '打开相机失败' });
    }
  }

  /**
   * 相册选择图片
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
        promptAction.showToast({ message: '图片选择成功' });
        this.startImageSearch();
      }
    } catch (err) {
      promptAction.showToast({ message: '选择图片失败' });
    }
  }

  /**
   * 模拟以图搜图逻辑
   */
  startImageSearch(): void {
    const resultList: ArtifactItem[] = [];

    for (let i = 0; i < 3; i++) {
      const item = this.mockArtifacts[i];

      const resultItem: ArtifactItem = {
        id: item.id,
        name: item.name,
        era: item.era,
        image: item.image,
        similarity: Math.floor(Math.random() * 36) + 60
      };

      resultList.push(resultItem);
    }

    const routerOptions: RouterOptions = {
      url: 'pages/ImageSearchResultPage',
      params: {
        image: this.selectedImage,
        results: JSON.stringify(resultList)
      }
    };

    router.pushUrl(routerOptions);
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

      Button('拍照搜索文物')
        .width('100%')
        .height(54)
        .fontSize(16)
        .backgroundColor('#C76B5A')           // 与文字搜索同色，统一柔和红
        .fontColor(Color.White)
        .borderRadius(12)
        .onClick(async () => {
          await this.openCamera();
        })

      Button('从相册选择图片')
        .width('100%')
        .height(54)
        .fontSize(16)
        .backgroundColor('#A68B6A')           // 浅褐
        .fontColor(Color.White)
        .borderRadius(12)
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
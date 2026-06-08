// entry/src/main/ets/pages/DiscoverPage.ets
// 顶部导入
import { DEFAULT_TOP_K, DEFAULT_THRESHOLD } from '../common/Constants';
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
  @State isVoiceSearching: boolean = false;

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
      const TOP_K = DEFAULT_TOP_K;
      const THRESHOLD = DEFAULT_THRESHOLD;

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
      Scroll() {
        Column({ space: 18 }) {
          this.headerSection()

          this.voiceSearchCard()

          this.imageSearchCard()

          this.bottomGuidePanel()

          Blank()
            .height(40)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F0E8')
  }

  @Builder
  headerSection() {
    Stack() {
      Column()
        .width(190)
        .height(190)
        .backgroundColor('#A84235')
        .opacity(0.18)
        .borderRadius(95)
        .position({ x: -70, y: -88 })

      Column()
        .width(150)
        .height(150)
        .backgroundColor('#F4D8B0')
        .opacity(0.16)
        .borderRadius(75)
        .position({ x: 300, y: -48 })

      Row() {
        Column({ space: 6 }) {
          Text('发现')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .letterSpacing(4)

          Row({ space: 8 }) {
            Divider()
              .width(42)
              .strokeWidth(1)
              .color('#E7C9A1')
            Text('✦')
              .fontSize(13)
              .fontColor('#F4D8B0')
            Divider()
              .width(42)
              .strokeWidth(1)
              .color('#E7C9A1')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 4 }) {
          Text('语音识物')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#F8E6D0')
          Text('以图寻珍')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#F8E6D0')
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 34, right: 34, top: 8 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(128)
    .backgroundColor('#8B2F26')
    .borderRadius({ bottomLeft: 22, bottomRight: 22 })
    .clip(true)
    .shadow({
      radius: 14,
      color: '#22000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  quickGuideCard() {
    Row({ space: 12 }) {
      this.guideItem('🎙', '语音搜索', '说出关键词')
      Divider()
        .height(40)
        .strokeWidth(1)
        .color('#EFE1D2')
      this.guideItem('📷', '以图搜图', '拍照或相册')
    }
    .width('94%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#FFFCF7')
    .borderRadius(20)
    .margin({ top: -10 })
    .shadow({
      radius: 12,
      color: '#18000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  guideItem(icon: string, title: string, desc: string) {
    Row({ space: 10 }) {
      Text(icon)
        .fontSize(24)
        .width(42)
        .height(42)
        .textAlign(TextAlign.Center)
        .backgroundColor('#F7EDE3')
        .borderRadius(21)

      Column({ space: 3 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3F3328')
        Text(desc)
          .fontSize(12)
          .fontColor('#9A7A5C')
      }
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
  }

  /**
   * 语音搜索模块（功能不变，UI 美化）
   */
  @Builder
  voiceSearchCard() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('语音搜索')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3F3328')
          Text('说出文物名称、年代、类型或博物馆')
            .fontSize(12)
            .fontColor('#9A7A5C')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('提示')
          .width(70)
          .height(32)
          .fontSize(12)
          .backgroundColor('#F6E6D8')
          .fontColor('#9A3D33')
          .borderRadius(16)
          .onClick(() => {
            MuseumVoiceService.speak(
              '欢迎使用掌上博物馆语音搜索，请说出你想查找的文物名称、年代、类型或博物馆名称。'
            );
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 6 }) {
        Text('推荐')
          .fontSize(12)
          .fontColor('#FFFFFF')
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor('#C05243')
          .borderRadius(12)
        Text('青花 · 唐三彩 · 玉琮 · 青铜')
          .fontSize(13)
          .fontColor('#8B7355')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      TextInput({ placeholder: '请输入或说出文物名称、年代、类型...', text: this.searchInput })
        .width('100%')
        .height(48)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#EFE1D2' })
        .borderRadius(16)
        .fontColor('#3A3A3A')
        .placeholderColor('#A9998B')
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.searchInput = value;
        })

      Row({ space: 10 }) {
        Button(this.isVoiceSearching ? '搜索中...' : '文字搜索')
          .layoutWeight(1)
          .height(46)
          .fontSize(15)
          .backgroundColor('#C05243')
          .fontColor(Color.White)
          .borderRadius(18)
          .enabled(!this.isVoiceSearching)
          .onClick(async () => {
            if (!this.searchInput.trim()) {
              promptAction.showToast({ message: '请输入搜索内容' });
              return;
            }
            this.voiceText = this.searchInput;
            this.isVoiceSearching = true;
            try {
              await MuseumVoiceService.handleVoiceSearch(this.searchInput);
            } finally {
              this.isVoiceSearching = false;
            }
          })

        Button(this.isVoiceSearching ? '识别中...' : '开始识别')
          .layoutWeight(1)
          .height(46)
          .fontSize(15)
          .backgroundColor('#9A7A5C')
          .fontColor(Color.White)
          .borderRadius(18)
          .enabled(!this.isVoiceSearching)
          .onClick(async () => {
            const hasPermission = await this.requestMicrophonePermission();
            if (!hasPermission) {
              return;
            }
            promptAction.showToast({ message: '请说出文物关键词' });
            this.isVoiceSearching = true;
            MuseumVoiceService.startVoiceSearch((text: string) => {
              this.voiceText = text;
              this.searchInput = text;
            }, () => {
              this.isVoiceSearching = false;
            });
          })
      }
      .width('100%')

      Button('结束语音识别')
        .width('100%')
        .height(42)
        .fontSize(14)
        .backgroundColor('#F1E6DA')
        .fontColor('#8B7355')
        .borderRadius(16)
        .onClick(() => {
          MuseumVoiceService.finishVoiceSearch();
          this.isVoiceSearching = false;
        })

      if (this.voiceText) {
        Text(`识别 / 搜索结果：${this.voiceText}`)
          .fontSize(14)
          .fontColor('#C05243')
          .alignSelf(ItemAlign.Start)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor('#FFF5EE')
          .borderRadius(12)
      }
    }
    .width('94%')
    .padding(22)
    .backgroundColor('#FFFCF7')
    .borderRadius(22)
    .shadow({
      radius: 10,
      color: '#16000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  /**
   * 以图搜图模块（功能不变，UI 美化）
   */
  @Builder
  imageSearchCard() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('以图搜图')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3F3328')
          Text('拍照或选择图片，匹配相似馆藏')
            .fontSize(12)
            .fontColor('#9A7A5C')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('📷')
          .fontSize(26)
          .width(46)
          .height(46)
          .textAlign(TextAlign.Center)
          .backgroundColor('#F6E6D8')
          .borderRadius(23)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 10 }) {
        Button(this.isSearching ? '搜索中...' : '拍照搜索')
          .layoutWeight(1)
          .height(48)
          .fontSize(15)
          .backgroundColor('#C05243')
          .fontColor(Color.White)
          .borderRadius(18)
          .enabled(!this.isSearching)
          .onClick(async () => {
            await this.openCamera();
          })

        Button(this.isSearching ? '搜索中...' : '相册选择')
          .layoutWeight(1)
          .height(48)
          .fontSize(15)
          .backgroundColor('#9A7A5C')
          .fontColor(Color.White)
          .borderRadius(18)
          .enabled(!this.isSearching)
          .onClick(async () => {
            await this.openAlbum();
          })
      }
      .width('100%')

      Column({ space: 8 }) {
        Text('使用说明')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#6B5540')
          .alignSelf(ItemAlign.Start)
        Text('建议选择主体清晰、光线充足的文物图片，系统会返回相似度较高的馆藏结果。')
          .fontSize(13)
          .fontColor('#9A7A5C')
          .lineHeight(20)
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F8F0E8')
      .borderRadius(14)

      if (this.selectedImage) {
        Text('已选择图片，正在准备识别')
          .fontSize(14)
          .fontColor('#C05243')
          .alignSelf(ItemAlign.Start)
      }
    }
    .width('94%')
    .padding(22)
    .backgroundColor('#FFFCF7')
    .borderRadius(22)
    .shadow({
      radius: 10,
      color: '#16000000',
      offsetX: 0,
      offsetY: 4
    })
  }
  @Builder
  bottomGuidePanel() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('探索提示')
            .fontSize(21)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3F3328')
          Text('让语音识别与以图搜图更适合平板展示')
            .fontSize(12)
            .fontColor('#9A7A5C')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('Museum Guide')
          .fontSize(12)
          .fontColor('#C05243')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 10 }) {
        this.tipItem('01', '说关键词', '名称、年代、材质')
        this.tipItem('02', '选清晰图', '主体完整更准确')
        this.tipItem('03', '看结果页', '查看相似馆藏')
      }
      .width('100%')
    }
    .width('94%')
    .padding(18)
    .backgroundColor('#FFFCF7')
    .borderRadius(22)
    .shadow({
      radius: 10,
      color: '#14000000',
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  tipItem(index: string, title: string, desc: string) {
    Column({ space: 7 }) {
      Text(index)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#C05243')

      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3F3328')

      Text(desc)
        .fontSize(11)
        .fontColor('#9A7A5C')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ top: 14, bottom: 14, left: 8, right: 8 })
    .backgroundColor('#F8F0E8')
    .borderRadius(16)
    .alignItems(HorizontalAlign.Center)
  }

}
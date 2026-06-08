import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { ReviewStatus, UploadedPhotoItem } from '../common/models/InteractionModels';
import { InteractionService } from '../common/services/InteractionService';
import { formatDateTime, formatReviewColor, formatReviewStatus } from '../common/utils/InteractionFormatUtil';
import { pickSingleImageUri } from '../common/utils/PhotoPickerUtil';

@Entry
@Component
export struct MyUploadsPage {
  @StorageLink('isLogin') isLogin: boolean = false;
  @StorageLink('username') username: string = '';
  @State uploads: UploadedPhotoItem[] = [];
  @State isLoading: boolean = true;
  @State isUploading: boolean = false;
  @State draftLocation: string = '';
  @State draftDescription: string = '';
  private reviewRefreshTimer: number = -1;

  aboutToAppear() {
    this.clearReviewRefreshTimer();
    this.loadUploads();
  }

  aboutToDisappear() {
    this.clearReviewRefreshTimer();
  }

  async loadUploads() {
    this.isLoading = true;
    this.uploads = await InteractionService.getUploads(this.username);
    this.isLoading = false;
    if (this.uploads.some((item: UploadedPhotoItem) => item.status === ReviewStatus.Pending)) {
      this.scheduleReviewRefresh();
    } else {
      this.clearReviewRefreshTimer();
    }
  }

  private clearReviewRefreshTimer() {
    if (this.reviewRefreshTimer > -1) {
      clearTimeout(this.reviewRefreshTimer);
      this.reviewRefreshTimer = -1;
    }
  }

  private scheduleReviewRefresh() {
    this.clearReviewRefreshTimer();
    this.reviewRefreshTimer = setTimeout(() => {
      this.reviewRefreshTimer = -1;
      this.loadUploads();
    }, 1600);
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('<')
          .fontSize(22)
          .fontColor('#C05040')            // 敦煌红返回箭头
          .onClick(() => router.back())
        Text('上传的照片')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3A3A3A')            // 主文字色
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text(' ')
          .width(22)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#F5F0E8')          // 与页面背景融合

      Scroll() {
        Column({ space: 16 }) {
          this.UploadEditor()

          if (this.isLoading) {
            LoadingProgress()
              .width(40)
              .height(40)
              .margin({ top: 24 })
              .color('#C05040')
          } else if (this.uploads.length === 0) {
            this.EmptyHint('还没有上传照片，先挑一张参观照片吧')
          } else {
            Column({ space: 12 }) {
              ForEach(this.uploads, (item: UploadedPhotoItem) => {
                this.UploadCard(item)
              }, (item: UploadedPhotoItem) => item.id)
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F0E8')
  }

  @Builder
  UploadEditor() {
    Column({ space: 10 }) {
      Text('上传参观照片')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')               // 标题主色
        .alignSelf(ItemAlign.Start)

      Text('照片会先进入审核，可补充拍摄地点和一句简短说明。')
        .fontSize(13)
        .fontColor('#8B7355')               // 辅助文字色
        .alignSelf(ItemAlign.Start)

      TextInput({ placeholder: '拍摄地点，例如：大英博物馆东馆', text: this.draftLocation })
        .height(44)
        .width('100%')
        .fontColor('#3A3A3A')
        .placeholderColor('#999999')
        .backgroundColor('#FFFFFF')
        .borderRadius(10)
        .border({ width: 1, color: '#E0D5C6' })
        .onChange((value: string) => {
          this.draftLocation = value;
        })

      TextInput({ placeholder: '简短说明，例如：现场人很多，但这件器物很震撼', text: this.draftDescription })
        .height(44)
        .width('100%')
        .fontColor('#3A3A3A')
        .placeholderColor('#999999')
        .backgroundColor('#FFFFFF')
        .borderRadius(10)
        .border({ width: 1, color: '#E0D5C6' })
        .onChange((value: string) => {
          this.draftDescription = value;
        })

      Button(this.isUploading ? '正在选择照片...' : '选择照片并上传', { type: ButtonType.Capsule })
        .width('100%')
        .height(44)
        .fontSize(15)
        .backgroundColor('#C05040')         // 敦煌红按钮
        .fontColor(Color.White)
        .enabled(!this.isUploading)
        .onClick(() => {
          this.handleUpload('', '参观随拍');
        })
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#F2EDE8')             // 暖米色卡片
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  EmptyHint(message: string) {
    Column() {
      Text(message)
        .fontSize(15)
        .fontColor('#8B7355')               // 辅助色提示
    }
    .width('100%')
    .padding({ top: 24, bottom: 8 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  UploadCard(item: UploadedPhotoItem) {
    Column() {
      Image(item.imageUri)
        .width('100%')
        .height(180)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)
        .backgroundColor('#E0D5C6')          // 浅米色占位

      Row() {
        Column() {
          Text(item.artifactTitle || '未关联文物')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3A3A3A')
          if (item.location) {
            Text(`拍摄地点：${item.location}`)
              .fontSize(13)
              .fontColor('#8B7355')
              .margin({ top: 4 })
          }
          if (item.description) {
            Text(item.description)
              .fontSize(13)
              .fontColor('#8B7355')
              .margin({ top: 4 })
          }
          Text(formatDateTime(item.createdAt))
            .fontSize(12)
            .fontColor('#8B7355')
            .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(formatReviewStatus(item.status))
          .fontSize(12)
          .fontColor(formatReviewColor(item.status))
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F2EDE8')             // 暖米色卡片
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  async handleUpload(artifactId: string, artifactTitle: string) {
    if (!this.isLogin || !this.username) {
      promptAction.showToast({ message: '请先登录后再上传照片' });
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    if (this.isUploading) {
      return;
    }
    this.isUploading = true;
    const imageUri = await pickSingleImageUri();
    this.isUploading = false;
    if (!imageUri) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    const result = await InteractionService.addUpload(context, {
      artifactId: artifactId,
      artifactTitle: artifactTitle,
      username: this.username,
      imageUri: imageUri,
      location: this.draftLocation,
      description: this.draftDescription
    });
    if (result.ok) {
      this.draftDescription = '';
    }
    promptAction.showToast({ message: result.message });
    await this.loadUploads();
    this.scheduleReviewRefresh();
  }
}

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UploadedPhotoItem } from '../common/models/InteractionModels';
import { interactionStore } from '../common/store/InteractionStore';
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

  aboutToAppear() {
    this.loadUploads();
  }

  async loadUploads() {
    this.isLoading = true;
    this.uploads = await interactionStore.getUploads(this.username);
    this.isLoading = false;
  }

  build() {
    Column() {
      Row() {
        Text('<')
          .fontSize(22)
          .fontColor('#007AFF')
          .onClick(() => router.back())
        Text('上传的照片')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('上传')
          .fontSize(15)
          .fontColor('#007AFF')
          .onClick(() => {
            this.handleUpload('', '参观随拍');
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF')

      if (this.isLoading) {
        LoadingProgress().width(40).height(40).margin({ top: 80 })
      } else if (this.uploads.length === 0) {
        this.EmptyHint('还没有上传照片，点击右上角上传')
      } else {
        List({ space: 12 }) {
          ForEach(this.uploads, (item: UploadedPhotoItem) => {
            ListItem() {
              this.UploadCard(item)
            }
          }, (item: UploadedPhotoItem) => item.id)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 12, bottom: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  EmptyHint(message: string) {
    Column() {
      Text(message)
        .fontSize(15)
        .fontColor('#999999')
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
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
        .backgroundColor('#DDDDDD')

      Row() {
        Column() {
          Text(item.artifactTitle || '未关联文物')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
          if (item.location) {
            Text(`地点：${item.location}`)
              .fontSize(13)
              .fontColor('#666666')
              .margin({ top: 4 })
          }
          if (item.description) {
            Text(item.description)
              .fontSize(13)
              .fontColor('#666666')
              .margin({ top: 4 })
          }
          Text(formatDateTime(item.createdAt))
            .fontSize(12)
            .fontColor('#999999')
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
    .backgroundColor('#FFFFFF')
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
    await interactionStore.addUpload({
      artifactId: artifactId,
      artifactTitle: artifactTitle,
      username: this.username,
      imageUri: imageUri,
      location: '',
      description: ''
    });
    promptAction.showToast({ message: '照片已上传，等待审核' });
    await this.loadUploads();
  }
}
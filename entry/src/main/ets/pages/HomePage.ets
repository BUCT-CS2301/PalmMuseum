// pages/HomePage.ets
import router from '@ohos.router';
import { Artifact, mockArtifacts } from '../common/models/Artifact';

@Entry
@Component
export struct HomePage {
  @State artifactList: Artifact[] = mockArtifacts;

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('海外藏中国文物')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
      }
      .width('100%')
      .height(56)
      .backgroundColor('#F5F5F5')

      // 文物列表
      List({ space: 12 }) {
        ForEach(this.artifactList, (item: Artifact) => {
          ListItem() {
            this.ArtifactCard(item)
          }
        }, (item: Artifact) => item.id)
      }
      .padding({ left: 16, right: 16, top: 12 })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F0F0')
  }

  @Builder
  ArtifactCard(item: Artifact) {
    Row() {
      Column() {
        Image(item.imageUrl)
          .width(80)
          .height(80)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
          .backgroundColor('#CCCCCC')
          .alt($r('app.media.startIcon'))
      }
      .width(80)
      .height(80)

      Column() {
        Text(item.title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${item.period} · ${item.type}`)
          .fontSize(14)
          .fontColor('#666666')
          .margin({ top: 4 })
        Text(item.museum)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12 })
      .layoutWeight(1)
    }
    .width('100%')
    .height(100)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .padding({ left: 12, right: 12 })
    .shadow({ radius: 4, color: '#1A000000' })
    .onClick(() => {
      // 点击跳转到详情页，并传递文物ID
      router.pushUrl({
        url: 'pages/ArtifactDetailPage',
        params: { id: item.id }
      });
    })
  }
}
import router from '@ohos.router';
import { HistoryItem } from '../common/models/InteractionModels';
import { interactionStore } from '../common/store/InteractionStore';
import { formatDateTime } from '../common/utils/InteractionFormatUtil';

@Entry
@Component
export struct MyHistoryPage {
  @StorageLink('username') username: string = '';
  @State historyList: HistoryItem[] = [];
  @State isLoading: boolean = true;

  aboutToAppear() {
    this.loadHistory();
  }

  async loadHistory() {
    this.isLoading = true;
    this.historyList = await interactionStore.getHistory(this.username);
    this.isLoading = false;
  }

  build() {
    Column() {
      this.PageHeader('浏览记录')

      if (this.isLoading) {
        LoadingProgress().width(40).height(40).margin({ top: 80 })
      } else if (this.historyList.length === 0) {
        this.EmptyHint('暂无浏览记录，浏览文物详情后会自动记录')
      } else {
        List({ space: 12 }) {
          ForEach(this.historyList, (item: HistoryItem) => {
            ListItem() {
              this.HistoryRow(item)
            }
          }, (item: HistoryItem) => `${item.artifactId}-${item.viewedAt}`)
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
  PageHeader(title: string) {
    Row() {
      Text('<')
        .fontSize(22)
        .fontColor('#007AFF')
        .onClick(() => router.back())
      Text(title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text(' ')
        .width(22)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#FFFFFF')
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
  HistoryRow(item: HistoryItem) {
    Row() {
      Image(item.imageUrl)
        .width(72)
        .height(72)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)
        .backgroundColor('#DDDDDD')
        .alt($r('app.media.startIcon'))

      Column() {
        Text(item.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${item.period} · ${item.museum}`)
          .fontSize(13)
          .fontColor('#666666')
          .margin({ top: 4 })
        Text(`浏览于 ${formatDateTime(item.viewedAt)}`)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/ArtifactDetailPage',
        params: { id: item.artifactId }
      });
    })
  }
}
// pages/MyLikesPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { interactionStore } from '../common/store/InteractionStore';
import { LikeItem } from '../common/models/InteractionModels';
import { formatDateTime } from '../common/utils/InteractionFormatUtil';

@Entry
@Component
export struct MyLikesPage {
  @StorageLink('username') username: string = '';
  @State likes: LikeItem[] = [];
  @State isLoading: boolean = true;

  aboutToAppear() {
    this.loadLikes();
  }

  async loadLikes() {
    if (!this.username) {
      promptAction.showToast({ message: '请先登录' });
      router.back();
      return;
    }
    this.isLoading = true;
    this.likes = await interactionStore.getLikes(this.username);
    this.isLoading = false;
  }

  build() {
    Column() {
      // 导航栏：返回箭头 + 居中标题
      Row() {
        Text('<')
          .fontSize(22)
          .fontColor('#C05040')
          .onClick(() => router.back())
        Text('我的点赞')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3A3A3A')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text(' ')
          .width(22)  // 占位，使标题真正居中
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#F5F0E8')

      if (this.isLoading) {
        LoadingProgress()
          .width(40).height(40)
          .margin({ top: 80 })
          .color('#C05040')
      } else if (this.likes.length === 0) {
        this.EmptyHint()
      } else {
        List({ space: 12 }) {
          ForEach(this.likes, (item: LikeItem) => {
            ListItem() {
              this.LikeRow(item)
            }
          }, (item: LikeItem) => item.artifactId)
        }
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 12, bottom: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F0E8')
  }

  @Builder
  EmptyHint() {
    Column() {
      Text('还没有点赞记录')
        .fontSize(15)
        .fontColor('#8B7355')
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  LikeRow(item: LikeItem) {
    Column() {
      Row() {
        Image(item.imageUrl)
          .width(72)
          .height(72)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
          .backgroundColor('#E0D5C6')

        Column() {
          Text(item.title)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3A3A3A')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${item.period} · ${item.museum}`)
            .fontSize(13)
            .fontColor('#8B7355')
            .margin({ top: 4 })
          Text(`点赞时间：${formatDateTime(item.likedAt)}`)
            .fontSize(12)
            .fontColor('#8B7355')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 12 })
        .layoutWeight(1)
      }
      .width('100%')
      .onClick(() => {
        router.pushUrl({
          url: 'pages/ArtifactDetailPage',
          params: { id: item.artifactId }
        });
      })

      // 操作行：取消点赞
      Row() {
        Blank()
        Text('取消点赞')
          .fontSize(13)
          .fontColor('#C05040')
          .onClick(async () => {
            await interactionStore.removeLike(item.artifactId, this.username);
            promptAction.showToast({ message: '已取消点赞' });
            await this.loadLikes();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F2EDE8')
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }
}
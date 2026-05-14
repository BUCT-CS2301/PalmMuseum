// pages/ArtifactDetailPage.ets
import router from '@ohos.router';
import { Artifact, mockArtifacts } from '../common/models/Artifact';
import promptAction from '@ohos.promptAction';

@Entry
@Component
export struct ArtifactDetailPage {
  @State artifact: Artifact | null = null;
  private artifactId: string = '';

  aboutToAppear() {
    // 获取路由传递的参数
    const params = router.getParams() as Record<string, string>;
    if (params && params.id) {
      this.artifactId = params.id;
      // 根据ID从Mock数据中查找文物
      const found = mockArtifacts.find(item => item.id === this.artifactId);
      this.artifact = found || null;
    }
  }

  build() {
    Column() {
      if (this.artifact) {
        // 滚动区域，避免内容过长
        Scroll() {
          Column() {
            // 高清图片（支持点击全屏预览，先简单展示）
            Image(this.artifact.imageUrl)
              .width('100%')
              .height(400)
              .objectFit(ImageFit.Cover)
              .backgroundColor('#CCCCCC')
              .alt($r('app.media.startIcon'))

            // 文物基本信息卡片
            Column() {
              Text(this.artifact.title)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .margin({ bottom: 12 })

              Row() {
                this.InfoChip('年代', this.artifact.period)
                this.InfoChip('类型', this.artifact.type)
                this.InfoChip('材质', this.artifact.material)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceAround)
              .margin({ bottom: 16 })

              Text('收藏机构：' + this.artifact.museum)
                .fontSize(16)
                .fontColor('#666666')
                .margin({ bottom: 24 })

              Text('文物介绍')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })

              Text(this.artifact.description)
                .fontSize(16)
                .lineHeight(24)
                .textAlign(TextAlign.Start)
                .margin({ bottom: 30 })

              // 功能按钮行
              Row() {
                Button('🔊 语音讲解')
                  .backgroundColor('#007AFF')
                  .onClick(() => {
                    // 预留：范力烨实现语音播放
                    this.showToast('语音讲解功能开发中');
                  })
                Button('❤️ 点赞')
                  .backgroundColor('#FF9500')
                  .onClick(() => {
                    // 预留：刘清实现点赞
                    this.showToast('点赞功能开发中');
                  })
                Button('⭐ 收藏')
                  .backgroundColor('#28A745')
                  .onClick(() => {
                    // 预留：刘清实现收藏
                    this.showToast('收藏功能开发中');
                  })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceAround)
              .margin({ bottom: 30 })

              // 评论区占位
              Column() {
                Text('评论区')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .alignSelf(ItemAlign.Start)
                Text('评论功能开发中...')
                  .fontSize(14)
                  .fontColor('#999999')
                  .margin({ top: 8 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .margin({ bottom: 20 })
            }
            .padding(16)
            .alignItems(HorizontalAlign.Center)
          }
        }
        .scrollBar(BarState.Auto)
      } else {
        // 文物不存在的情况
        Column() {
          Text('未找到该文物')
            .fontSize(20)
            .fontColor('#FF0000')
          Button('返回首页')
            .margin({ top: 20 })
            .onClick(() => {
              router.back();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  InfoChip(label: string, value: string) {
    Column() {
      Text(label).fontSize(12).fontColor('#999999')
      Text(value).fontSize(16).fontWeight(FontWeight.Medium).margin({ top: 4 })
    }
  }

  private showToast(message: string) {
    try {
      promptAction.showToast({ message: message });
    } catch (error) {
      console.error('Toast显示失败：' + JSON.stringify(error));
    }
  }
}

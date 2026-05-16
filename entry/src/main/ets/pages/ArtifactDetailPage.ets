// pages/ArtifactDetailPage.ets
import router from '@ohos.router';
import { Artifact, mockArtifacts } from '../common/models/Artifact';
import promptAction from '@ohos.promptAction';
import { MuseumVoiceService } from '../common/voice/MuseumVoiceService';
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
              Column({ space: 12 }) {
                Row({ space: 12 }) {
                  Button('🎧 语音讲解', { type: ButtonType.Capsule })
                    .layoutWeight(1)
                    .height(44)
                    .fontSize(15)
                    .backgroundColor('#1677FF')
                    .fontColor(Color.White)
                    .onClick(() => {
                      if (this.artifact !== null) {
                        const text = MuseumVoiceService.buildArtifactGuide(this.artifact);
                        MuseumVoiceService.speak(text);
                        this.showToast('正在播放语音讲解');
                      }
                    })

                  Button('🎙️ 语音问答', { type: ButtonType.Capsule })
                    .layoutWeight(1)
                    .height(44)
                    .fontSize(15)
                    .backgroundColor('#8E44AD')
                    .fontColor(Color.White)
                    .onClick(() => {
                      if (this.artifact !== null) {
                        const question = '这个文物在哪个博物馆';
                        const answer = MuseumVoiceService.answerQuestion(this.artifact, question);
                        MuseumVoiceService.speak(answer);
                        this.showToast(answer);
                      }
                    })
                }
                .width('100%')

                Row({ space: 12 }) {
                  Button('❤️ 点赞', { type: ButtonType.Capsule })
                    .layoutWeight(1)
                    .height(44)
                    .fontSize(15)
                    .backgroundColor('#FF7A00')
                    .fontColor(Color.White)
                    .onClick(() => {
                      this.showToast('点赞成功');
                    })

                  Button('⭐ 收藏', { type: ButtonType.Capsule })
                    .layoutWeight(1)
                    .height(44)
                    .fontSize(15)
                    .backgroundColor('#18A058')
                    .fontColor(Color.White)
                    .onClick(() => {
                      this.showToast('收藏成功');
                    })
                }
                .width('100%')
              }
              .width('100%')
              .margin({ top: 20 })

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

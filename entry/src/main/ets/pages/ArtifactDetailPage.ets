
import router from '@ohos.router';
import { Artifact, mockArtifacts } from '../common/models/Artifact';
import promptAction from '@ohos.promptAction';
import { MuseumVoiceService } from '../common/voice/MuseumVoiceService';

// 关联实体接口
interface RelatedEntity {
  title: string;
  id: string;
}

@Entry
@Component
export struct ArtifactDetailPage {
  @State artifact: Artifact | null = null;
  private artifactId: string = '';

  @State scaleValue: number = 1;
  @State offsetX: number = 0;
  @State offsetY: number = 0;

  @State relatedEntities: RelatedEntity[] = [];
  @State relatedList: Artifact[] = [];
  @State currentImageIndex: number = 0;

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params && params['objectId']) {
      this.artifactId = params['objectId'];
      const found = mockArtifacts.find(item => item.id === this.artifactId);
      this.artifact = found || null;
      if (this.artifact) {
        this.loadRelatedData();
      }
    }
  }

  private loadRelatedData() {
    if (!this.artifact) return;

    this.relatedEntities = mockArtifacts
      .filter(a => a.period === this.artifact!.period && a.id !== this.artifact!.id)
      .map(a => ({ title: a.title, id: a.id } as RelatedEntity));

    this.relatedList = mockArtifacts
      .filter(a => a.id !== this.artifact!.id &&
        (a.period === this.artifact!.period || a.type === this.artifact!.type))
      .slice(0, 4);
  }

  build() {
    Column() {
      if (this.artifact) {
        Scroll() {
          Column() {
            // 图片区域
            Stack() {
              Image(this.artifact.imageUrl)
                .width('100%')
                .height(400)
                .objectFit(ImageFit.Cover)
                .backgroundColor('#CCCCCC')
                .alt($r('app.media.startIcon'))
                .scale({ x: this.scaleValue, y: this.scaleValue })
                .offset({ x: this.offsetX, y: this.offsetY })
                .gesture(
                  GestureGroup(GestureMode.Parallel,
                    PinchGesture()
                      .onActionUpdate((event: GestureEvent) => {
                        this.scaleValue = event.scale;
                      })
                      .onActionEnd(() => {
                        if (this.scaleValue < 0.5) this.scaleValue = 0.5;
                        if (this.scaleValue > 3) this.scaleValue = 3;
                      }),
                    PanGesture({ fingers: 2 })
                      .onActionUpdate((event: GestureEvent) => {
                        this.offsetX = event.offsetX;
                        this.offsetY = event.offsetY;
                      })
                  )
                )

              Text(`${this.currentImageIndex + 1}/1`)
                .fontSize(12)
                .fontColor('#FFFFFF')
                .backgroundColor('#80000000')
                .borderRadius(10)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .position({ x: '90%', y: '90%' })
            }
            .width('100%')
            .height(400)
            .backgroundColor('#FAFAFA')

            // 基本信息
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
                .margin({ bottom: 20 })

              // 同朝代关联实体
              if (this.relatedEntities.length > 0) {
                Column() {
                  Text('同朝代文物')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .alignSelf(ItemAlign.Start)
                    .margin({ bottom: 8 })

                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.relatedEntities, (entity: RelatedEntity) => {
                      Text(entity.title)
                        .fontSize(13)
                        .fontColor('#1A73E8')
                        .backgroundColor('#E8F0FE')
                        .borderRadius(12)
                        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                        .margin({ right: 8, bottom: 6 })
                        .onClick(() => {
                          router.replaceUrl({
                            url: 'pages/ArtifactDetailPage',
                            params: { objectId: entity.id }
                          });
                        })
                    }, (entity: RelatedEntity) => entity.id)
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .margin({ bottom: 20 })
              }

              // 相关推荐
              if (this.relatedList.length > 0) {
                Column() {
                  Text('相关推荐')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .alignSelf(ItemAlign.Start)
                    .margin({ bottom: 8 })

                  Scroll() {
                    Row() {
                      ForEach(this.relatedList, (item: Artifact) => {
                        Column() {
                          Image(item.imageUrl)
                            .width(120)
                            .height(120)
                            .objectFit(ImageFit.Cover)
                            .borderRadius(8)
                            .alt($r('app.media.startIcon'))

                          Text(item.title)
                            .fontSize(12)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .width(120)
                            .margin({ top: 4 })

                          Text(item.period)
                            .fontSize(11)
                            .fontColor('#888')
                        }
                        .margin({ right: 8 })
                        .onClick(() => {
                          router.replaceUrl({
                            url: 'pages/ArtifactDetailPage',
                            params: { objectId: item.id }
                          });
                        })
                      }, (item: Artifact) => item.id)
                    }
                    .padding({ left: 0, right: 0, top: 8, bottom: 16 })
                  }
                  .scrollable(ScrollDirection.Horizontal)
                  .scrollBar(BarState.Off)
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .margin({ bottom: 20 })
              }

              // 功能按钮（融合语音功能）
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
                        try {
                          const text = MuseumVoiceService.buildArtifactGuide(this.artifact);
                          MuseumVoiceService.speak(text);
                          this.showToast('正在播放语音讲解');
                        } catch (e) {
                          this.showToast('语音服务暂不可用');
                        }
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
                        try {
                          const question = '这个文物在哪个博物馆';
                          const answer = MuseumVoiceService.answerQuestion(this.artifact, question);
                          MuseumVoiceService.speak(answer);
                          this.showToast(answer);
                        } catch (e) {
                          this.showToast('语音问答暂不可用');
                        }
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
        Column() {
          Text('未找到该文物')
            .fontSize(20)
            .fontColor('#FF0000')
          Button('返回首页')
            .margin({ top: 20 })
            .onClick(() => router.back())
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
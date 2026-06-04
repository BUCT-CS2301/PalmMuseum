import common from '@ohos.app.ability.common';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Artifact } from '../common/models/Artifact';
import { MuseumArtifactApi, ArtifactSearchResult } from '../common/network/MuseumArtifactApi';
import {
  CommentItem,
  FAVORITE_GROUPS,
  InteractionSummary,
  ReviewStatus
} from '../common/models/InteractionModels';
import { interactionStore } from '../common/store/InteractionStore';
import { formatDateTime, formatReviewColor, formatReviewStatus } from '../common/utils/InteractionFormatUtil';
import { pickSingleImageUri } from '../common/utils/PhotoPickerUtil';
import { MuseumVoiceService } from '../common/voice/MuseumVoiceService';
import { QaImage, QaSource } from '../common/services/QaChatService';

interface RelatedEntity {
  title: string;
  id: string;
}

@Entry
@Component
export struct ArtifactDetailPage {
  @StorageLink('isLogin') isLogin: boolean = false;
  @StorageLink('username') username: string = '';
  @State artifact: Artifact | null = null;
  @State likeSummary: InteractionSummary = { active: false, count: 0 };
  @State favoriteSummary: InteractionSummary = { active: false, count: 0 };
  @State favoriteGroups: string[] = [];
  @State comments: CommentItem[] = [];
  @State commentInput: string = '';
  @State isSubmittingComment: boolean = false;
  @State isUploadingPhoto: boolean = false;
  @State selectedFavoriteGroup: string = FAVORITE_GROUPS[0];
  @State uploadLocation: string = '';
  @State uploadDescription: string = '';
  @State replyTarget: CommentItem | null = null;
  private artifactId: string = '';
  private reviewRefreshTimer: number = -1;

  @State scaleValue: number = 1;
  @State offsetX: number = 0;
  @State offsetY: number = 0;

  @State relatedEntities: RelatedEntity[] = [];
  @State relatedList: Artifact[] = [];
  @State currentImageIndex: number = 0;
  @State allImageUrls: string[] = [];
  @State currentVoiceSpeed: number = 1;
  @State voiceProgressText: string = '0 / 0';
  @State voiceQuestionInput: string = '';
  @State voiceQuestionText: string = '';
  @State voiceAnswerText: string = '';
  @State voiceAnswerSources: QaSource[] = [];
  @State voiceAnswerImages: QaImage[] = [];
  @State isVoiceAsking: boolean = false;
  @State isRecognizingQuestion: boolean = false;
  @State showFullDescription: boolean = false;
  @State showVoiceQuestionPanel: boolean = false;
  @State showVoiceControls: boolean = false;
  @State showAllComments: boolean = false;

  aboutToAppear() {
    this.clearReviewRefreshTimer();
    const params = router.getParams() as Record<string, string>;
    const id = params ? (params['objectId'] || params['id']) : '';
    if (!id) {
      return;
    }
    this.artifactId = id;
    this.loadArtifactDetail(id);
  }

  private async loadArtifactDetail(id: string) {
    try {
      const detail: Artifact = await MuseumArtifactApi.getArtifactDetail(id);
      this.artifact = detail;
      this.allImageUrls = detail.imageUrls && detail.imageUrls.length > 0
        ? detail.imageUrls
        : [detail.imageUrl];
      this.currentImageIndex = 0;
      this.scaleValue = 1;
      this.offsetX = 0;
      this.offsetY = 0;
      this.commentInput = '';
      this.voiceQuestionInput = '';
      this.voiceQuestionText = '';
      this.voiceAnswerText = '';
      this.voiceAnswerSources = [];
      this.voiceAnswerImages = [];
      this.isVoiceAsking = false;
      this.isRecognizingQuestion = false;
      this.showVoiceQuestionPanel = false;
      this.showVoiceControls = false;
      this.showAllComments = false;
      this.replyTarget = null;
      this.uploadDescription = '';
      this.uploadLocation = detail.museum;
      await this.loadRelatedData();
      await this.initInteractionData();
    } catch (e) {
      console.error(`[ArtifactDetailPage] 加载文物详情失败：${JSON.stringify(e)}`);
      this.artifact = null;
    }
  }

  aboutToDisappear() {
    this.clearReviewRefreshTimer();
  }

  private async loadRelatedData() {
    if (!this.artifact) {
      return;
    }

    try {
      const result: ArtifactSearchResult = await MuseumArtifactApi.searchArtifacts({
        page: 1,
        size: 8,
        period: this.artifact.period,
        type: this.artifact.type
      });

      const related = result.items.filter((item: Artifact) => item.id !== this.artifact!.id);
      this.relatedEntities = related
        .filter((item: Artifact) => item.period === this.artifact!.period)
        .map((item: Artifact) => ({ title: item.title, id: item.id } as RelatedEntity));
      this.relatedList = related.slice(0, 4);
    } catch (e) {
      console.error(`[ArtifactDetailPage] 加载相关推荐失败：${JSON.stringify(e)}`);
      this.relatedEntities = [];
      this.relatedList = [];
    }
  }

  private resolveActor(): string {
    return this.isLogin && this.username ? this.username : '';
  }

  private async initInteractionData() {
    if (!this.artifact) {
      return;
    }
    if (this.isLogin && this.username) {
      await interactionStore.recordHistory(this.artifact, this.username);
      this.favoriteGroups = await interactionStore.getFavoriteGroups(this.username);
      this.selectedFavoriteGroup = await interactionStore.getFavoriteGroupForArtifact(this.username, this.artifact.id);
    } else {
      this.favoriteGroups = FAVORITE_GROUPS;
      this.selectedFavoriteGroup = FAVORITE_GROUPS[0];
    }
    await this.refreshInteractionState();
  }

  private async refreshInteractionState() {
    if (!this.artifact) {
      return;
    }
    const actor = this.resolveActor();
    this.likeSummary = await interactionStore.getLikeSummary(this.artifact.id, actor);
    this.favoriteSummary = await interactionStore.getFavoriteSummary(this.artifact.id, actor);
    this.comments = await interactionStore.getCommentsForArtifact(this.artifact.id, actor);
    if (this.comments.some((item: CommentItem) => item.status === ReviewStatus.Pending)) {
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
      this.refreshInteractionState();
    }, 1600);
  }

  private getRootComments(): CommentItem[] {
    return this.comments.filter((item: CommentItem) => !item.parentId);
  }

  private getVisibleRootComments(): CommentItem[] {
    const rootComments: CommentItem[] = this.getRootComments();
    if (this.showAllComments) {
      return rootComments;
    }
    return rootComments.slice(0, 3);
  }

  private getChildComments(parentId: string): CommentItem[] {
    return this.comments.filter((item: CommentItem) => item.parentId === parentId);
  }

  private getCommentDisplayName(item: CommentItem): string {
    return item.displayName || item.username || '匿名用户';
  }

  private getCommentProfileUsername(item: CommentItem): string {
    return item.profileUsername || item.username || '';
  }

  private openCommentProfile(item: CommentItem): void {
    const profileUsername = this.getCommentProfileUsername(item);
    const displayName = this.getCommentDisplayName(item);
    if (!profileUsername && !displayName) {
      this.showToast('暂时无法查看该用户信息');
      return;
    }

    router.pushUrl({
      url: 'pages/OtherProfilePage',
      params: {
        username: profileUsername,
        nickname: displayName,
        avatar: item.avatar || '',
        userId: item.userId || ''
      }
    });
  }

  private buildCommentActionLabel(item: CommentItem): string {
    return item.likedByCurrentUser ? `已赞 ${item.likeCount || 0}` : `点赞 ${item.likeCount || 0}`;
  }

  private buildCommentRenderKey(item: CommentItem): string {
    const likedFlag = item.likedByCurrentUser ? '1' : '0';
    const likeCount = item.likeCount || 0;
    return `${item.id}-${likeCount}-${likedFlag}`;
  }

  build() {
    Column() {
      if (this.artifact) {
        Scroll() {
          Column() {
            this.ImageSection()
            this.BasicInfoSection()

            if (this.relatedEntities.length > 0) {
              this.RelatedEntitySection()
            }

            if (this.relatedList.length > 0) {
              this.RelatedListSection()
            }

            this.InteractionSection()
            this.VoiceSection()
            this.CommentSection()
            this.UploadSection()
          }
          .width('100%')
          .padding({ bottom: 18 })
        }
        .scrollBar(BarState.Auto)
      } else {
        Column() {
          Text('未找到该文物')
            .fontSize(20)
            .fontColor('#C05040')
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
    .backgroundColor('#F7F0E7')
  }

  @Builder
  ImageSection() {
    Stack() {
      Swiper() {
        ForEach(this.allImageUrls, (url: string, index: number) => {
          Image(url)
            .width('100%')
            .height(310)
            .objectFit(ImageFit.Cover)
            .backgroundColor('#E8DED2')
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
                    if (this.scaleValue < 0.5) {
                      this.scaleValue = 0.5;
                    }
                    if (this.scaleValue > 3) {
                      this.scaleValue = 3;
                    }
                  }),
                PanGesture({ fingers: 2 })
                  .onActionUpdate((event: GestureEvent) => {
                    this.offsetX = event.offsetX;
                    this.offsetY = event.offsetY;
                  })
              )
            )
        }, (url: string, index: number) => index.toString())
      }
      .index(this.currentImageIndex)
      .autoPlay(false)
      .indicator(false)
      .onChange((index: number) => {
        this.currentImageIndex = index;
      })
      .width('100%')
      .height(310)

      Row() {
        Text('‹')
          .fontSize(32)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor('#7A000000')
          .borderRadius(18)
          .onClick(() => {
            router.back();
          })

        Blank()

        Text(`${this.currentImageIndex + 1}/${this.allImageUrls.length}`)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .backgroundColor('#7A000000')
          .borderRadius(12)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 18 })
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .height(310)
    .backgroundColor('#F7F0E7')
  }

  @Builder
  BasicInfoSection() {
    Column({ space: 12 }) {
      Text(this.artifact!.title)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2F241F')
        .width('100%')
        .textAlign(TextAlign.Start)

      Row() {
        Text('')
          .width(46)
          .height(4)
          .backgroundColor('#B94A3D')
          .borderRadius(2)
        Text('')
          .width(92)
          .height(1)
          .backgroundColor('#E2C8B2')
          .margin({ left: 8 })
      }
      .width('100%')

      Text(this.artifact!.museum)
        .fontSize(14)
        .fontColor('#8A6D55')
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Flex({ wrap: FlexWrap.Wrap }) {
        this.TagChip(this.artifact!.period || '年代不详')
        this.TagChip(this.artifact!.type || '类型不详')
        this.TagChip(this.artifact!.material || '材质不详')
      }
      .width('100%')

      Divider()
        .strokeWidth(0.5)
        .color('#E0D5C6')

      Row() {
        Text('文物介绍')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2F241F')

        Blank()

        Text(this.showFullDescription ? '收起' : '展开')
          .fontSize(13)
          .fontColor('#C05040')
          .onClick(() => {
            this.showFullDescription = !this.showFullDescription;
          })
      }
      .width('100%')

      Text(this.artifact!.description)
        .fontSize(15)
        .fontColor('#2F241F')
        .lineHeight(23)
        .maxLines(this.showFullDescription ? 50 : 6)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFCF7')
    .borderRadius(24)
    .shadow({ radius: 16, color: '#1A000000', offsetX: 0, offsetY: 6 })
    .margin({ left: 12, right: 12, top: -28, bottom: 12 })
  }

  @Builder
  TagChip(value: string) {
    Text(value)
      .fontSize(12)
      .fontColor('#8A6D55')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor('#F1E8DF')
      .borderRadius(16)
      .margin({ right: 8, bottom: 4 })
  }

  @Builder
  RelatedEntitySection() {
    Column() {
      Text('同年代文物')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2F241F')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 8 })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.relatedEntities, (entity: RelatedEntity) => {
          Text(entity.title)
            .fontSize(13)
            .fontColor('#8A6D55')
            .backgroundColor('#F2EDE8')
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
    .backgroundColor('#FFFCF7')
    .borderRadius(22)
    .padding(16)
    .shadow({ radius: 12, color: '#12000000', offsetX: 0, offsetY: 4 })
    .margin({ left: 12, right: 12, bottom: 12 })
  }

  @Builder
  RelatedListSection() {
    Column() {
      Text('相关推荐')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2F241F')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 8 })

      Scroll() {
        Row() {
          ForEach(this.relatedList, (item: Artifact) => {
            Column() {
              Image(item.imageUrl)
                .width('100%')
                .height(150)
                .objectFit(ImageFit.Cover)
                .backgroundColor('#F7F0E7')
                .borderRadius(8)

              Text(item.title)
                .fontSize(12)
                .fontColor('#2F241F')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width(116)
                .margin({ top: 4 })

              Text(item.period)
                .fontSize(11)
                .fontColor('#8A6D55')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width(116)
            }
            .margin({ right: 10 })
            .onClick(() => {
              router.replaceUrl({
                url: 'pages/ArtifactDetailPage',
                params: { objectId: item.id }
              });
            })
          }, (item: Artifact) => item.id)
        }
        .padding({ top: 8, bottom: 12 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FFFCF7')
    .borderRadius(22)
    .padding(16)
    .shadow({ radius: 12, color: '#12000000', offsetX: 0, offsetY: 4 })
    .margin({ left: 12, right: 12, bottom: 12 })
  }

  @Builder
  InteractionSection() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Button(this.likeSummary.active ? `已点赞 ${this.likeSummary.count}` : `点赞 ${this.likeSummary.count}`, { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .backgroundColor(this.likeSummary.active ? '#C05040' : '#F2EDE8')
          .fontColor(this.likeSummary.active ? Color.White : '#8B7355')
          .onClick(() => {
            this.handleToggleLike();
          })

        Button(this.favoriteSummary.active ? `已收藏 ${this.favoriteSummary.count}` : `收藏 ${this.favoriteSummary.count}`, { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .backgroundColor(this.favoriteSummary.active ? '#8B7355' : '#F2EDE8')
          .fontColor(this.favoriteSummary.active ? Color.White : '#8B7355')
          .onClick(() => {
            this.handleToggleFavorite();
          })
      }
      .width('100%')

      this.FavoriteGroupSelector()
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFCF7')
    .borderRadius(22)
    .shadow({ radius: 12, color: '#12000000', offsetX: 0, offsetY: 4 })
    .margin({ left: 12, right: 12, bottom: 12 })
  }

  @Builder
  VoiceSection() {
    Column({ space: 12 }) {
      Row() {
        Text('语音导览')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2F241F')

        Blank()

        Text(this.showVoiceControls ? `播放中 · ${this.voiceProgressText}` : '讲解 / 问答')
          .fontSize(12)
          .fontColor('#8A6D55')
      }
      .width('100%')

      Row({ space: 10 }) {
        Button(this.showVoiceControls ? '继续讲解' : '语音讲解', { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(42)
          .fontSize(15)
          .backgroundColor('#B94A3D')
          .fontColor(Color.White)
          .onClick(async () => {
            if (this.artifact !== null) {
              try {
                const text = MuseumVoiceService.buildArtifactGuide(this.artifact);
                this.showVoiceControls = true;
                await MuseumVoiceService.speak(text, this.currentVoiceSpeed);
                this.voiceProgressText = MuseumVoiceService.getProgressText();
                this.showToast(`正在以 ${this.currentVoiceSpeed}x 播放语音讲解`);
              } catch (error) {
                this.showToast('语音服务暂不可用');
              }
            }
          })

        Button(this.showVoiceQuestionPanel ? '收起问答' : 'AI 问答', { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(42)
          .fontSize(15)
          .backgroundColor(this.showVoiceQuestionPanel ? '#C05040' : '#8B7355')
          .fontColor(Color.White)
          .enabled(!this.isVoiceAsking)
          .onClick(() => {
            this.showVoiceQuestionPanel = !this.showVoiceQuestionPanel;
          })
      }
      .width('100%')

      if (this.showVoiceQuestionPanel) {
        Column({ space: 10 }) {
          TextInput({
            placeholder: '输入关于该文物的问题，例如：它收藏在哪里？',
            text: this.voiceQuestionInput
          })
            .width('100%')
            .height(42)
            .fontSize(14)
            .backgroundColor('#F8F3EF')
            .borderRadius(12)
            .enabled(!this.isVoiceAsking)
            .padding({ left: 12, right: 12 })
            .onChange((value: string) => {
              this.voiceQuestionInput = value;
            })

          Row({ space: 8 }) {
            Button(this.isVoiceAsking ? '生成中...' : '提问并播报')
              .layoutWeight(1)
              .height(36)
              .fontSize(13)
              .backgroundColor('#B94A3D')
              .fontColor(Color.White)
              .enabled(!this.isVoiceAsking)
              .onClick(async () => {
                this.showVoiceControls = true;
                await this.handleAskVoiceQuestion();
              })

            Button(this.isRecognizingQuestion ? '识别中...' : '语音提问')
              .layoutWeight(1)
              .height(36)
              .fontSize(13)
              .backgroundColor('#8A6D55')
              .fontColor(Color.White)
              .enabled(!this.isVoiceAsking)
              .onClick(() => {
                this.showVoiceControls = true;
                this.handleStartVoiceQuestion();
              })

            if (this.isRecognizingQuestion) {
              Button('结束')
                .width(64)
                .height(36)
                .fontSize(13)
                .backgroundColor('#F2EDE8')
                .fontColor('#8A6D55')
                .onClick(() => {
                  this.finishVoiceQuestionRecognition();
                })
            }
          }
          .width('100%')

          if (this.voiceQuestionText.length > 0 || this.voiceAnswerText.length > 0 || this.isVoiceAsking) {
            Column({ space: 8 }) {
              if (this.voiceQuestionText.length > 0) {
                Text(`问题：${this.voiceQuestionText}`)
                  .fontSize(13)
                  .fontColor('#8A6D55')
                  .lineHeight(20)
                  .alignSelf(ItemAlign.Start)
              }

              Text(this.voiceAnswerText.length > 0 ? this.voiceAnswerText : '正在生成回答...')
                .fontSize(14)
                .fontColor('#2F241F')
                .lineHeight(22)
                .width('100%')

              if (this.voiceAnswerSources.length > 0) {
                Column({ space: 4 }) {
                  Text('参考来源')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#8A6D55')
                    .alignSelf(ItemAlign.Start)

                  ForEach(this.voiceAnswerSources, (source: QaSource, index: number) => {
                    Text(source.url.length > 0 ? `${source.name}：${source.url}` : source.name)
                      .fontSize(12)
                      .fontColor('#8A6D55')
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                  }, (source: QaSource, index: number) => index.toString())
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }

              if (this.voiceAnswerImages.length > 0) {
                Scroll() {
                  Row({ space: 8 }) {
                    ForEach(this.voiceAnswerImages, (image: QaImage, index: number) => {
                      Image(image.url)
                        .width(96)
                        .height(72)
                        .objectFit(ImageFit.Contain)
                        .backgroundColor('#F7F0E7')
                        .borderRadius(8)
                        .alt($r('app.media.startIcon'))
                    }, (image: QaImage, index: number) => index.toString())
                  }
                  .padding({ top: 4, bottom: 4 })
                }
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .width('100%')
              }
            }
            .width('100%')
            .padding(10)
            .backgroundColor('#F8F3EF')
            .borderRadius(12)
            .alignItems(HorizontalAlign.Start)
          }
        }
        .width('100%')
      }

      if (this.showVoiceControls) {
        Divider()
          .strokeWidth(0.5)
          .color('#E0D5C6')

        Column({ space: 10 }) {
          Row() {
            Text('播放控制')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#2F241F')

            Blank()

            Text(`当前段落：${this.voiceProgressText}`)
              .fontSize(12)
              .fontColor('#8A6D55')
          }
          .width('100%')

          Row({ space: 8 }) {
            this.SpeedButton('0.75x', 0.75)
            this.SpeedButton('1x', 1)
            this.SpeedButton('1.25x', 1.25)
            this.SpeedButton('1.5x', 1.5)
          }
          .width('100%')

          Row({ space: 8 }) {
            Button('上一段')
              .layoutWeight(1)
              .height(36)
              .fontSize(13)
              .backgroundColor('#F2EDE8')
              .fontColor('#8A6D55')
              .onClick(() => {
                MuseumVoiceService.previousParagraph();
                this.voiceProgressText = MuseumVoiceService.getProgressText();
              })

            Button('下一段')
              .layoutWeight(1)
              .height(36)
              .fontSize(13)
              .backgroundColor('#F2EDE8')
              .fontColor('#8A6D55')
              .onClick(() => {
                MuseumVoiceService.nextParagraph();
                this.voiceProgressText = MuseumVoiceService.getProgressText();
              })
          }
          .width('100%')

          Row({ space: 8 }) {
            Button('停止')
              .layoutWeight(1)
              .height(36)
              .fontSize(13)
              .backgroundColor('#B94A3D')
              .fontColor(Color.White)
              .onClick(() => {
                MuseumVoiceService.stop();
                this.showVoiceControls = false;
              })

            Button('重播')
              .layoutWeight(1)
              .height(36)
              .fontSize(13)
              .backgroundColor('#8A6D55')
              .fontColor(Color.White)
              .onClick(() => {
                MuseumVoiceService.replay();
                this.voiceProgressText = MuseumVoiceService.getProgressText();
              })
          }
          .width('100%')
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFCF7')
    .borderRadius(22)
    .shadow({ radius: 12, color: '#12000000', offsetX: 0, offsetY: 4 })
    .margin({ left: 12, right: 12, bottom: 12 })
  }

  @Builder
  SpeedButton(label: string, speed: number) {
    Button(label)
      .layoutWeight(1)
      .height(34)
      .fontSize(13)
      .backgroundColor(this.currentVoiceSpeed === speed ? '#C05040' : '#F2EDE8')
      .fontColor(this.currentVoiceSpeed === speed ? Color.White : '#8B7355')
      .onClick(() => {
        this.currentVoiceSpeed = speed;
        MuseumVoiceService.setSpeed(speed);
      })
  }

  @Builder
  FavoriteGroupSelector() {
    Column({ space: 8 }) {
      Row() {
        Text('收藏分组')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2F241F')
        Blank()
        Text(this.favoriteSummary.active ? `当前：${this.selectedFavoriteGroup}` : '选择后加入收藏')
          .fontSize(12)
          .fontColor('#8A6D55')
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.favoriteGroups, (groupName: string) => {
          Text(groupName)
            .fontSize(12)
            .fontColor(this.selectedFavoriteGroup === groupName ? '#FFFFFF' : '#8B7355')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.selectedFavoriteGroup === groupName ? '#8B7355' : '#F2EDE8')
            .borderRadius(14)
            .margin({ right: 8, top: 4 })
            .onClick(() => {
              this.handleFavoriteGroupSelect(groupName);
            })
        }, (groupName: string) => groupName)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  CommentSection() {
    Column() {
      Row() {
        Text(`评论区（${this.comments.length}）`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2F241F')
        Blank()
        Text('公开评论')
          .fontSize(12)
          .fontColor('#8A6D55')
      }
      .width('100%')
      .margin({ bottom: 8 })

      Text('新评论需审核后公开显示，待审核评论仅自己可见。')
        .fontSize(12)
        .fontColor('#8A6D55')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 12 })

      if (this.comments.length === 0) {
        Text('暂无评论，快来抢沙发')
          .fontSize(14)
          .fontColor('#8A6D55')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 12 })
      } else {
        Column({ space: 10 }) {
          ForEach(this.getVisibleRootComments(), (item: CommentItem) => {
            this.CommentThreadItemView(item, 0)
          }, (item: CommentItem) => this.buildCommentRenderKey(item))
        }
        .width('100%')
        .margin({ bottom: 10 })

        if (this.getRootComments().length > 3) {
          Button(this.showAllComments ? '收起评论' : `查看全部 ${this.getRootComments().length} 条评论`)
            .width('100%')
            .height(38)
            .fontSize(13)
            .backgroundColor('#F2EDE8')
            .fontColor('#8A6D55')
            .borderRadius(19)
            .margin({ bottom: 12 })
            .onClick(() => {
              this.showAllComments = !this.showAllComments;
            })
        }
      }

      if (!this.replyTarget) {
        Row({ space: 8 }) {
          TextInput({
            placeholder: '写下你的看法…',
            text: this.commentInput
          })
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .backgroundColor('#F8F3EF')
            .borderRadius(21)
            .padding({ left: 14, right: 12 })
            .onChange((value: string) => {
              this.commentInput = value;
            })

          Button('发表')
            .width(68)
            .height(42)
            .fontSize(14)
            .backgroundColor('#B94A3D')
            .fontColor(Color.White)
            .borderRadius(21)
            .enabled(!this.isSubmittingComment)
            .onClick(() => {
              this.handleSubmitComment();
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FFFCF7')
    .borderRadius(22)
    .padding(16)
    .shadow({ radius: 12, color: '#12000000', offsetX: 0, offsetY: 4 })
    .margin({ left: 12, right: 12, bottom: 12 })
  }

  @Builder
  CommentThreadItemView(item: CommentItem, level: number = 0) {
    Column({ space: 10 }) {
      Row() {
        Text(this.getCommentDisplayName(item))
          .fontSize(level > 0 ? 13 : 14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2F241F')
          .onClick(() => {
            this.openCommentProfile(item);
          })
        Blank()
        Text(formatReviewStatus(item.status))
          .fontSize(12)
          .fontColor(formatReviewColor(item.status))
      }
      .width('100%')

      if (item.replyTo) {
        Text(`回复 ${item.replyTo}`)
          .fontSize(12)
          .fontColor('#C05040')
      }

      Text(item.content)
        .fontSize(level > 0 ? 14 : 15)
        .lineHeight(22)
        .fontColor('#2F241F')
        .width('100%')

      Row() {
        Text(formatDateTime(item.createdAt))
          .fontSize(12)
          .fontColor('#8A6D55')
        Blank()
        if (item.status === ReviewStatus.Approved) {
          Text(this.buildCommentActionLabel(item))
            .fontSize(12)
            .fontColor(item.likedByCurrentUser ? '#FFFFFF' : '#8B7355')
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(item.likedByCurrentUser ? '#C05040' : '#F2EDE8')
            .borderRadius(14)
            .onClick(() => {
              this.handleToggleCommentLike(item);
            })

          Text('回复')
            .fontSize(12)
            .fontColor(this.replyTarget && this.replyTarget.id === item.id ? '#FFFFFF' : '#8B7355')
            .margin({ left: 10 })
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(this.replyTarget && this.replyTarget.id === item.id ? '#C05040' : '#F2EDE8')
            .borderRadius(14)
            .onClick(() => {
              this.prepareReply(item);
            })
        } else {
          Text('审核中，仅自己可见')
            .fontSize(12)
            .fontColor('#FF7A00')
        }
      }
      .width('100%')

      if (this.replyTarget && this.replyTarget.id === item.id) {
        Column({ space: 8 }) {
          Row() {
            Text(`回复 ${this.getCommentDisplayName(item)}`)
              .fontSize(12)
              .fontColor('#C05040')
            Blank()
            Text('取消')
              .fontSize(12)
              .fontColor('#FF4D4F')
              .onClick(() => {
                this.replyTarget = null;
                this.commentInput = '';
              })
          }
          .width('100%')

          Row({ space: 8 }) {
            TextInput({
              placeholder: `回复 ${this.getCommentDisplayName(item)}…`,
              text: this.commentInput
            })
              .layoutWeight(1)
              .height(40)
              .fontSize(14)
              .backgroundColor('#FFFFFF')
              .borderRadius(20)
              .border({ width: 1, color: '#E0D5C6' })
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.commentInput = value;
              })

            Button('发送')
              .width(64)
              .height(40)
              .fontSize(13)
              .backgroundColor('#B94A3D')
              .fontColor(Color.White)
              .borderRadius(20)
              .enabled(!this.isSubmittingComment)
              .onClick(() => {
                this.handleSubmitComment();
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(10)
        .backgroundColor('#F8F3EF')
        .borderRadius(12)
      }

      if (this.getChildComments(item.id).length > 0) {
        Column({ space: 8 }) {
          ForEach(this.getChildComments(item.id), (child: CommentItem) => {
            this.CommentThreadItemView(child, level + 1)
          }, (child: CommentItem) => this.buildCommentRenderKey(child))
        }
        .width('100%')
        .padding({ left: 12 })
      }
    }
    .width('100%')
    .padding(12)
    .margin({ left: level * 8 })
    .backgroundColor(level > 0 ? '#F2EDE8' : '#FFFFFF')
    .borderRadius(10)
    .border({ width: 1, color: '#E0D5C6' })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  UploadSection() {
    Column({ space: 10 }) {
      Text('上传参观照片')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2F241F')
        .alignSelf(ItemAlign.Start)

      Text('上传的照片会先进入审核，可补充拍摄地点和简短说明。')
        .fontSize(12)
        .fontColor('#8A6D55')
        .alignSelf(ItemAlign.Start)

      TextInput({ placeholder: '拍摄地点', text: this.uploadLocation })
        .height(42)
        .width('100%')
        .fontSize(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .padding({ left: 14, right: 12 })
        .onChange((value: string) => {
          this.uploadLocation = value;
        })

      TextInput({ placeholder: '简短说明', text: this.uploadDescription })
        .height(42)
        .width('100%')
        .fontSize(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .padding({ left: 14, right: 12 })
        .onChange((value: string) => {
          this.uploadDescription = value;
        })

      Button(this.isUploadingPhoto ? '正在选择照片...' : '选择照片并上传', { type: ButtonType.Capsule })
        .width('100%')
        .height(44)
        .fontSize(15)
        .backgroundColor('#B94A3D')
        .fontColor(Color.White)
        .enabled(!this.isUploadingPhoto)
        .onClick(() => {
          this.handleUploadPhoto();
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F4E8DE')
    .borderRadius(22)
    .shadow({ radius: 12, color: '#12000000', offsetX: 0, offsetY: 4 })
    .margin({ left: 12, right: 12, bottom: 22 })
    .alignItems(HorizontalAlign.Start)
  }

  private buildDefaultVoiceQuestion(): string {
    if (!this.artifact) {
      return '';
    }

    const input = this.voiceQuestionInput.trim();
    if (input.length > 0) {
      return input;
    }

    return `${this.artifact.title}收藏在哪个博物馆？`;
  }

  private buildAiQuestion(rawQuestion: string): string {
    if (!this.artifact) {
      return rawQuestion.trim();
    }

    const question = rawQuestion.trim();
    return `当前文物信息：名称是${this.artifact.title}，年代是${this.artifact.period}，类型是${this.artifact.type}，材质是${this.artifact.material}，收藏机构是${this.artifact.museum}，简介是${this.artifact.description}。用户问题：${question}`;
  }

  private async handleAskVoiceQuestion(rawQuestion?: string) {
    if (!this.artifact || this.isVoiceAsking) {
      return;
    }

    const displayQuestion = (rawQuestion || this.buildDefaultVoiceQuestion()).trim();
    if (displayQuestion.length === 0) {
      this.showToast('请输入或说出问题');
      return;
    }

    this.voiceQuestionInput = displayQuestion;
    this.voiceQuestionText = displayQuestion;
    this.voiceAnswerText = '';
    this.voiceAnswerSources = [];
    this.voiceAnswerImages = [];
    this.isVoiceAsking = true;
    this.showVoiceControls = true;

    try {
      const answer = await MuseumVoiceService.askAiQuestionAndSpeak(
        this.buildAiQuestion(displayQuestion),
        this.currentVoiceSpeed,
        {
          onAnswerUpdate: (text: string) => {
            this.voiceAnswerText = text;
          },
          onSource: (source: QaSource) => {
            this.voiceAnswerSources = [...this.voiceAnswerSources, source];
          },
          onImage: (image: QaImage) => {
            this.voiceAnswerImages = [...this.voiceAnswerImages, image];
          }
        }
      );

      this.voiceAnswerText = answer.answer;
      this.voiceAnswerSources = answer.sources;
      this.voiceAnswerImages = answer.images;
      this.voiceProgressText = MuseumVoiceService.getProgressText();
      this.showToast('AI回答已生成并开始播报');
    } catch (error) {
      console.error(`AI语音问答失败: ${JSON.stringify(error)}`);
      const fallbackAnswer = MuseumVoiceService.answerQuestion(this.artifact, displayQuestion);
      this.voiceAnswerText = fallbackAnswer;
      this.voiceAnswerSources = [];
      this.voiceAnswerImages = [];
      await MuseumVoiceService.speak(fallbackAnswer, this.currentVoiceSpeed);
      this.voiceProgressText = MuseumVoiceService.getProgressText();
      this.showToast('已生成回答并开始播报');
    } finally {
      this.isVoiceAsking = false;
    }
  }

  private handleStartVoiceQuestion() {
    if (this.isVoiceAsking || this.isRecognizingQuestion) {
      return;
    }

    this.isRecognizingQuestion = true;
    MuseumVoiceService.startVoiceQuestion(
      (text: string) => {
        this.voiceQuestionInput = text;
        this.isRecognizingQuestion = false;
        this.handleAskVoiceQuestion(text);
      },
      () => {
        this.isRecognizingQuestion = false;
      }
    );
  }

  private finishVoiceQuestionRecognition() {
    MuseumVoiceService.finishVoiceSearch();
    this.isRecognizingQuestion = false;
  }

  private async handleToggleLike() {
    if (!this.artifact) {
      return;
    }
    if (!this.isLogin || !this.username) {
      this.showToast('请先登录后再点赞');
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    this.likeSummary = await interactionStore.toggleLike(this.artifact.id, this.username, this.artifact);
    this.showToast(this.likeSummary.active ? '已点赞' : '已取消点赞');
  }

  private async handleToggleFavorite() {
    if (!this.artifact) {
      return;
    }
    if (!this.isLogin || !this.username) {
      this.showToast('请先登录后再收藏');
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    this.favoriteSummary = await interactionStore.toggleFavorite(this.artifact, this.username, this.selectedFavoriteGroup);
    if (this.favoriteSummary.active) {
      this.showToast(`已加入“${this.selectedFavoriteGroup}”`);
    } else {
      this.showToast('已取消收藏');
    }
    await this.refreshInteractionState();
  }

  private async handleFavoriteGroupSelect(groupName: string) {
    this.selectedFavoriteGroup = groupName;
    if (!this.favoriteSummary.active || !this.artifact || !this.isLogin || !this.username) {
      return;
    }
    await interactionStore.moveFavoriteToGroup(this.artifact.id, this.username, groupName);
    this.showToast(`已移动到“${groupName}”`);
    await this.refreshInteractionState();
  }

  private prepareReply(item: CommentItem) {
    if (!this.isLogin || !this.username) {
      this.showToast('请先登录后再回复评论');
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    this.replyTarget = item;
    this.commentInput = '';
  }

  private async handleToggleCommentLike(item: CommentItem) {
    if (!this.isLogin || !this.username) {
      this.showToast('请先登录后再点赞评论');
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    if (item.likedByCurrentUser) {
      this.showToast('你已经点赞过这条评论了');
      return;
    }
    const summary = await interactionStore.toggleCommentLike(item.id, this.username);
    this.comments = this.comments.map((comment: CommentItem) => {
      if (comment.id !== item.id) {
        return comment;
      }
      const nextComment: CommentItem = {
        id: comment.id,
        artifactId: comment.artifactId,
        artifactTitle: comment.artifactTitle,
        username: comment.username,
        displayName: comment.displayName,
        profileUsername: comment.profileUsername,
        userId: comment.userId,
        avatar: comment.avatar,
        content: comment.content,
        createdAt: comment.createdAt,
        status: comment.status,
        likeCount: summary.count,
        likedByCurrentUser: summary.active
      };
      if (comment.parentId) {
        nextComment.parentId = comment.parentId;
      }
      if (comment.replyTo) {
        nextComment.replyTo = comment.replyTo;
      }
      return nextComment;
    });
    if (this.artifact) {
      this.comments = await interactionStore.getCommentsForArtifact(this.artifact.id, this.username);
    }
    this.showToast('已点赞评论');
  }

  private async handleSubmitComment() {
    if (!this.artifact) {
      return;
    }
    if (!this.isLogin || !this.username) {
      this.showToast('请先登录后再评论');
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    if (this.isSubmittingComment) {
      return;
    }
    this.isSubmittingComment = true;
    const result = await interactionStore.addComment(
      this.artifact,
      this.username,
      this.commentInput,
      this.replyTarget ? this.replyTarget.id : '',
      this.replyTarget ? this.replyTarget.username : ''
    );
    this.isSubmittingComment = false;
    if (result.ok) {
      this.commentInput = '';
      this.replyTarget = null;
      await this.refreshInteractionState();
      this.scheduleReviewRefresh();
    }
    this.showToast(result.message);
  }

  private async handleUploadPhoto() {
    if (!this.artifact) {
      return;
    }
    if (!this.isLogin || !this.username) {
      this.showToast('请先登录后再上传照片');
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    if (this.isUploadingPhoto) {
      return;
    }
    this.isUploadingPhoto = true;
    const imageUri = await pickSingleImageUri();
    this.isUploadingPhoto = false;
    if (!imageUri) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    await interactionStore.addUpload(context, {
      artifactId: this.artifact.id,
      artifactTitle: this.artifact.title,
      username: this.username,
      imageUri: imageUri,
      location: this.uploadLocation.trim() || this.artifact.museum,
      description: this.uploadDescription.trim()
    });
    this.uploadDescription = '';
    this.showToast('照片已上传，等待审核');
  }

  private showToast(message: string) {
    try {
      promptAction.showToast({ message: message });
    } catch (error) {
      console.error(`Toast显示失败: ${JSON.stringify(error)}`);
    }
  }
}

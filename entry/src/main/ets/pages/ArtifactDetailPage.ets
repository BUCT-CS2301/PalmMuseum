import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Artifact, mockArtifacts } from '../common/models/Artifact';
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
  @State replyInput: string = '';
  @State isSubmittingComment: boolean = false;
  @State isUploadingPhoto: boolean = false;
  @State selectedFavoriteGroup: string = FAVORITE_GROUPS[0];
  @State showFavoriteDialog: boolean = false;
  @State favoriteDialogGroupName: string = FAVORITE_GROUPS[0];
  @State favoriteDialogNewGroupName: string = '';
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

  aboutToAppear() {
    this.clearReviewRefreshTimer();
    const params = router.getParams() as Record<string, string>;
    const id = params ? (params['objectId'] || params['id']) : '';
    if (!id) {
      return;
    }
    this.artifactId = id;
    const found = mockArtifacts.find((item: Artifact) => item.id === this.artifactId);
    this.artifact = found || null;
    if (!this.artifact) {
      return;
    }
    this.allImageUrls = this.artifact.imageUrls && this.artifact.imageUrls.length > 0
      ? this.artifact.imageUrls
      : [this.artifact.imageUrl];
    this.currentImageIndex = 0;
    this.scaleValue = 1;
    this.offsetX = 0;
    this.offsetY = 0;
    this.commentInput = '';
    this.replyInput = '';
    this.replyTarget = null;
    this.showFavoriteDialog = false;
    this.favoriteDialogNewGroupName = '';
    this.uploadDescription = '';
    this.uploadLocation = this.artifact.museum;
    this.loadRelatedData();
    this.initInteractionData();
  }

  aboutToDisappear() {
    this.clearReviewRefreshTimer();
  }

  private loadRelatedData() {
    if (!this.artifact) {
      return;
    }

    this.relatedEntities = mockArtifacts
      .filter((item: Artifact) => item.period === this.artifact!.period && item.id !== this.artifact!.id)
      .map((item: Artifact) => ({ title: item.title, id: item.id } as RelatedEntity));

    this.relatedList = mockArtifacts
      .filter((item: Artifact) => item.id !== this.artifact!.id &&
        (item.period === this.artifact!.period || item.type === this.artifact!.type))
      .slice(0, 4);
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
    this.favoriteDialogGroupName = this.selectedFavoriteGroup;
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

  private getCommentById(commentId: string): CommentItem | null {
    const found = this.comments.find((item: CommentItem) => item.id === commentId);
    return found || null;
  }

  private getThreadRootId(item: CommentItem): string {
    let current: CommentItem | null = item;
    let guard = 0;
    while (current && current.parentId && guard < this.comments.length) {
      const parent = this.getCommentById(current.parentId);
      if (!parent) {
        break;
      }
      current = parent;
      guard += 1;
    }
    return current ? current.id : item.id;
  }

  private getThreadReplies(rootId: string): CommentItem[] {
    return this.comments.filter((item: CommentItem) => {
      if (!item.parentId) {
        return false;
      }
      return this.getThreadRootId(item) === rootId;
    });
  }

  private resolveReplyParentId(item: CommentItem): string {
    return item.parentId ? this.getThreadRootId(item) : item.id;
  }

  private buildCommentActionLabel(item: CommentItem): string {
    return item.likedByCurrentUser ? `已赞 ${item.likeCount || 0}` : `点赞 ${item.likeCount || 0}`;
  }

  private buildCommentRenderKey(item: CommentItem): string {
    const likedFlag = item.likedByCurrentUser ? '1' : '0';
    const likeCount = item.likeCount || 0;
    return `${item.id}-${likeCount}-${likedFlag}`;
  }

  private buildCommentThreadKey(item: CommentItem): string {
    return `${this.buildCommentRenderKey(item)}-${this.getThreadReplies(item.id).length}`;
  }

  private isReplyingTo(item: CommentItem): boolean {
    return !!this.replyTarget && this.replyTarget.id === item.id;
  }

  build() {
    Stack() {
      Column() {
        if (this.artifact) {
          Scroll() {
            Column() {
              this.ImageSection()

              Column() {
                Text(this.artifact.title)
                  .fontSize(24)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#3A3A3A')
                  .margin({ bottom: 12 })

                Row() {
                  this.InfoChip('年代', this.artifact.period)
                  this.InfoChip('类型', this.artifact.type)
                  this.InfoChip('材质', this.artifact.material)
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceAround)
                .margin({ bottom: 16 })

                Text(`收藏机构：${this.artifact.museum}`)
                  .fontSize(16)
                  .fontColor('#8B7355')
                  .margin({ bottom: 24 })

                Text('文物介绍')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#3A3A3A')
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 8 })

                Text(this.artifact.description)
                  .fontSize(16)
                  .fontColor('#3A3A3A')
                  .lineHeight(24)
                  .textAlign(TextAlign.Start)
                  .margin({ bottom: 20 })
              }
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .padding(16)
              .margin({ left: 12, right: 12, top: 12, bottom: 8 })

              if (this.relatedEntities.length > 0) {
                this.RelatedEntitySection()
              }

              if (this.relatedList.length > 0) {
                this.RelatedListSection()
              }

              this.ActionSection()
              this.CommentSection()
              this.UploadSection()
            }
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
      .backgroundColor('#F5F0E8')

      if (this.showFavoriteDialog) {
        this.FavoriteDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  ImageSection() {
    Stack() {
      Swiper() {
        ForEach(this.allImageUrls, (url: string, index: number) => {
          Image(url)
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
      .height(400)

      Text(`${this.currentImageIndex + 1}/${this.allImageUrls.length}`)
        .fontSize(12)
        .fontColor('#FFFFFF')
        .backgroundColor('#80000000')
        .borderRadius(10)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .position({ x: '90%', y: '90%' })
    }
    .width('100%')
    .height(400)
    .backgroundColor('#F5F0E8')
  }

  @Builder
  RelatedEntitySection() {
    Column() {
      Text('同年代文物')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 8 })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.relatedEntities, (entity: RelatedEntity) => {
          Text(entity.title)
            .fontSize(13)
            .fontColor('#8B7355')
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
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .padding(12)
    .margin({ left: 12, right: 12, bottom: 8 })
  }

  @Builder
  RelatedListSection() {
    Column() {
      Text('相关推荐')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')
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
                .fontColor('#3A3A3A')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width(120)
                .margin({ top: 4 })

              Text(item.period)
                .fontSize(11)
                .fontColor('#8B7355')
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
        .padding({ top: 8, bottom: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .padding(12)
    .margin({ left: 12, right: 12, bottom: 8 })
  }

  @Builder
  ActionSection() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Button('语音讲解', { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .backgroundColor('#C05040')
          .fontColor(Color.White)
          .onClick(async () => {
            if (this.artifact !== null) {
              try {
                const text = MuseumVoiceService.buildArtifactGuide(this.artifact);
                await MuseumVoiceService.speak(text, this.currentVoiceSpeed);
                this.voiceProgressText = MuseumVoiceService.getProgressText();
                this.showToast(`正在以 ${this.currentVoiceSpeed}x 播放语音讲解`);
              } catch (error) {
                this.showToast('语音服务暂不可用');
              }
            }
          })

        Button('语音问答', { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .backgroundColor('#8B7355')
          .fontColor(Color.White)
          .onClick(async () => {
            if (this.artifact !== null) {
              try {
                const answer = MuseumVoiceService.answerQuestion(this.artifact, '这个文物收藏在哪个博物馆');
                await MuseumVoiceService.speak(answer, this.currentVoiceSpeed);
                this.voiceProgressText = MuseumVoiceService.getProgressText();
                this.showToast(answer);
              } catch (error) {
                this.showToast('语音问答暂不可用');
              }
            }
          })
      }
      .width('100%')

      Column({ space: 10 }) {
        Text('语音播放控制')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3A3A3A')
          .alignSelf(ItemAlign.Start)

        Row({ space: 8 }) {
          Button('0.75x')
            .layoutWeight(1)
            .height(36)
            .fontSize(13)
            .backgroundColor(this.currentVoiceSpeed === 0.75 ? '#C05040' : '#F2EDE8')
            .fontColor(this.currentVoiceSpeed === 0.75 ? Color.White : '#8B7355')
            .onClick(() => {
              this.currentVoiceSpeed = 0.75;
              MuseumVoiceService.setSpeed(0.75);
            })

          Button('1x')
            .layoutWeight(1)
            .height(36)
            .fontSize(13)
            .backgroundColor(this.currentVoiceSpeed === 1 ? '#C05040' : '#F2EDE8')
            .fontColor(this.currentVoiceSpeed === 1 ? Color.White : '#8B7355')
            .onClick(() => {
              this.currentVoiceSpeed = 1;
              MuseumVoiceService.setSpeed(1);
            })

          Button('1.25x')
            .layoutWeight(1)
            .height(36)
            .fontSize(13)
            .backgroundColor(this.currentVoiceSpeed === 1.25 ? '#C05040' : '#F2EDE8')
            .fontColor(this.currentVoiceSpeed === 1.25 ? Color.White : '#8B7355')
            .onClick(() => {
              this.currentVoiceSpeed = 1.25;
              MuseumVoiceService.setSpeed(1.25);
            })

          Button('1.5x')
            .layoutWeight(1)
            .height(36)
            .fontSize(13)
            .backgroundColor(this.currentVoiceSpeed === 1.5 ? '#C05040' : '#F2EDE8')
            .fontColor(this.currentVoiceSpeed === 1.5 ? Color.White : '#8B7355')
            .onClick(() => {
              this.currentVoiceSpeed = 1.5;
              MuseumVoiceService.setSpeed(1.5);
            })
        }
        .width('100%')

        Row({ space: 8 }) {
          Button('上一段')
            .layoutWeight(1)
            .height(38)
            .fontSize(14)
            .backgroundColor('#F2EDE8')
            .fontColor('#8B7355')
            .onClick(() => {
              MuseumVoiceService.previousParagraph();
              this.voiceProgressText = MuseumVoiceService.getProgressText();
            })

          Button('下一段')
            .layoutWeight(1)
            .height(38)
            .fontSize(14)
            .backgroundColor('#F2EDE8')
            .fontColor('#8B7355')
            .onClick(() => {
              MuseumVoiceService.nextParagraph();
              this.voiceProgressText = MuseumVoiceService.getProgressText();
            })
        }
        .width('100%')

        Row({ space: 8 }) {
          Button('停止')
            .layoutWeight(1)
            .height(38)
            .fontSize(14)
            .backgroundColor('#C05040')
            .fontColor(Color.White)
            .onClick(() => {
              MuseumVoiceService.stop();
            })

          Button('重播')
            .layoutWeight(1)
            .height(38)
            .fontSize(14)
            .backgroundColor('#8B7355')
            .fontColor(Color.White)
            .onClick(() => {
              MuseumVoiceService.replay();
              this.voiceProgressText = MuseumVoiceService.getProgressText();
            })
        }
        .width('100%')

        Text(`当前段落：${this.voiceProgressText}`)
          .fontSize(13)
          .fontColor('#8B7355')
          .alignSelf(ItemAlign.Start)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(Color.Transparent)

      Row({ space: 12 }) {
        Button(this.likeSummary.active ? `已赞 ${this.likeSummary.count}` : `点赞 ${this.likeSummary.count}`, { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .backgroundColor(this.likeSummary.active ? '#C05040' : '#F2EDE8')
          .fontColor(this.likeSummary.active ? Color.White : '#8B7355')
          .onClick(() => {
            this.handleToggleLike();
          })

        Button(this.favoriteSummary.active ? `已藏 ${this.favoriteSummary.count}` : `收藏 ${this.favoriteSummary.count}`, { type: ButtonType.Capsule })
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .backgroundColor(this.favoriteSummary.active ? '#8B7355' : '#F2EDE8')
          .fontColor(this.favoriteSummary.active ? Color.White : '#8B7355')
          .onClick(() => {
            this.handleOpenFavoriteDialog();
          })
      }
      .width('100%')

      if (this.favoriteSummary.active) {
        Text(`当前收藏夹：${this.selectedFavoriteGroup}`)
          .fontSize(12)
          .fontColor('#666666')
          .alignSelf(ItemAlign.Start)
      }
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .padding(12)
    .margin({ left: 12, right: 12, bottom: 8 })
  }

  @Builder
  FavoriteDialog() {
    Column() {
      Column({ space: 12 }) {
        Text(this.favoriteSummary.active ? '调整收藏分组' : '选择收藏夹')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)

        Text(this.favoriteSummary.active
          ? '你可以修改当前收藏所在分组，或者直接取消收藏。'
          : '请选择要加入的收藏夹，也可以先新建一个分组。')
          .fontSize(13)
          .fontColor('#666666')

        TextInput({
          placeholder: '新收藏夹名称（可选）',
          text: this.favoriteDialogNewGroupName
        })
          .height(42)
          .width('100%')
          .backgroundColor('#F7F8FA')
          .borderRadius(10)
          .onChange((value: string) => {
            this.favoriteDialogNewGroupName = value;
          })

        if (this.favoriteDialogNewGroupName.trim().length > 0) {
          Button('新建并选中这个收藏夹')
            .width('100%')
            .height(40)
            .fontSize(13)
            .backgroundColor('#EEF6FF')
            .fontColor('#1677FF')
            .onClick(() => {
              this.favoriteDialogGroupName = this.favoriteDialogNewGroupName.trim();
            })
        }

        Text('已有收藏夹')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .alignSelf(ItemAlign.Start)

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.favoriteGroups, (groupName: string) => {
            Text(groupName)
              .fontSize(12)
              .fontColor(this.favoriteDialogGroupName === groupName ? '#FFFFFF' : '#0E7A3E')
              .padding({ left: 10, right: 10, top: 8, bottom: 8 })
              .backgroundColor(this.favoriteDialogGroupName === groupName ? '#0E7A3E' : '#EAF7EF')
              .borderRadius(16)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                this.favoriteDialogGroupName = groupName;
              })
          }, (groupName: string) => groupName)
        }
        .width('100%')

        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .height(42)
            .backgroundColor('#F3F4F6')
            .fontColor('#666666')
            .onClick(() => {
              this.closeFavoriteDialog();
            })

          if (this.favoriteSummary.active) {
            Button('取消收藏')
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#FFF1F0')
              .fontColor('#FF4D4F')
              .onClick(() => {
                this.handleCancelFavorite();
              })
          }

          Button(this.favoriteSummary.active ? '保存分组' : '确认收藏')
            .layoutWeight(1)
            .height(42)
            .backgroundColor('#18A058')
            .fontColor(Color.White)
            .onClick(() => {
              this.handleConfirmFavoriteDialog();
            })
        }
        .width('100%')
      }
      .width('88%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(18)
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#66000000')
  }

  @Builder
  CommentSection() {
    Column() {
      Row() {
        Text(`评论区（${this.comments.length}）`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3A3A3A')
        Blank()
        Text('支持点赞、回复、楼中楼互动')
          .fontSize(12)
          .fontColor('#8B7355')
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text('回复会自动挂到对应主评论下，新评论与图片会在 1.5 秒内自动审核通过。')
        .fontSize(13)
        .fontColor('#8B7355')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 12 })

      this.BottomCommentBar()

      if (this.comments.length === 0) {
        Text('暂无评论，来发第一条吧')
          .fontSize(14)
          .fontColor('#8B7355')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 12 })
      } else {
        Column({ space: 10 }) {
          ForEach(this.getRootComments(), (item: CommentItem) => {
            this.CommentThreadItemView(item, 0)
          }, (item: CommentItem) => this.buildCommentThreadKey(item))
        }
        .width('100%')
        .margin({ bottom: 16 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .padding(12)
    .margin({ left: 12, right: 12, bottom: 8 })
  }

  @Builder
  BottomCommentBar() {
    Column() {
      Row() {
        TextInput({
          placeholder: '写下你的评论',
          text: this.commentInput
        })
          .layoutWeight(1)
          .height(42)
          .backgroundColor('#F7F8FA')
          .borderRadius(21)
          .padding({ left: 10, right: 10 })
          .onChange((value: string) => {
            this.commentInput = value;
          })

        Button('发送')
          .height(42)
          .fontSize(14)
          .backgroundColor('#C05040')
          .fontColor(Color.White)
          .enabled(!this.isSubmittingComment)
          .onClick(() => {
            this.handleSubmitComment();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 16 })
  }

  @Builder
  InlineReplyBar(item: CommentItem) {
    Column({ space: 8 }) {
      Row() {
        Text(`回复 @${item.username}`)
          .fontSize(12)
          .fontColor('#C05040')
        Blank()
        Text('取消')
          .fontSize(12)
          .fontColor('#FF4D4F')
          .onClick(() => {
            this.cancelReply();
          })
      }
      .width('100%')

      Row() {
        TextInput({
          placeholder: `回复 @${item.username}`,
          text: this.replyInput
        })
          .layoutWeight(1)
          .height(40)
          .backgroundColor('#FFFFFF')
          .borderRadius(20)
          .padding({ left: 10, right: 10 })
          .onChange((value: string) => {
            this.replyInput = value;
          })

        Button('回复')
          .height(40)
          .fontSize(13)
          .backgroundColor('#C05040')
          .fontColor(Color.White)
          .enabled(!this.isSubmittingComment)
          .onClick(() => {
            this.handleSubmitReply();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(10)
    .backgroundColor('#F2EDE8')
    .borderRadius(12)
    .margin({ top: 4 })
  }

  @Builder
  CommentThreadItemView(item: CommentItem, level: number = 0) {
    if (level > 0) {
      Column({ space: 8 }) {
        Row() {
          Row({ space: 4 }) {
            Text(item.username)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#3A3A3A')
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/OtherProfilePage',
                  params: { username: item.username }
                });
              })
            if (item.replyTo) {
              Text(`回复 @${item.replyTo}`)
                .fontSize(12)
                .fontColor('#C05040')
            }
          }
          Blank()
          if (item.status !== ReviewStatus.Approved) {
            Text(formatReviewStatus(item.status))
              .fontSize(11)
              .fontColor(formatReviewColor(item.status))
          }
        }
        .width('100%')

        Text(item.content)
          .fontSize(14)
          .lineHeight(20)
          .fontColor('#3A3A3A')
          .width('100%')

        Row() {
          Text(formatDateTime(item.createdAt))
            .fontSize(11)
            .fontColor('#8B7355')
          Blank()
          if (item.status === ReviewStatus.Approved) {
            Text(this.buildCommentActionLabel(item))
              .fontSize(11)
              .fontColor(item.likedByCurrentUser ? '#FFFFFF' : '#8B7355')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor(item.likedByCurrentUser ? '#C05040' : '#FFFFFF')
              .borderRadius(12)
              .border({
                width: 1,
                color: item.likedByCurrentUser ? '#C05040' : '#E0D5C6'
              })
              .onClick(() => {
                this.handleToggleCommentLike(item);
              })

            Text('回复')
              .fontSize(11)
              .fontColor('#8B7355')
              .margin({ left: 8 })
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor('#F2EDE8')
              .borderRadius(12)
              .onClick(() => {
                this.prepareReply(item);
              })
          }
        }
        .width('100%')

        if (this.isReplyingTo(item)) {
          this.InlineReplyBar(item)
        }
      }
      .width('100%')
      .padding(10)
      .backgroundColor(this.isReplyingTo(item) ? '#FAEFE9' : '#FFFFFF')
      .borderRadius(12)
      .border({
        width: 1,
        color: this.isReplyingTo(item) ? '#C05040' : '#E0D5C6'
      })
      .alignItems(HorizontalAlign.Start)
    } else {
      Column({ space: 12 }) {
        Row() {
          Text(item.username)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3A3A3A')
            .onClick(() => {
              router.pushUrl({
                url: 'pages/OtherProfilePage',
                params: { username: item.username }
              });
            })
          Blank()
          if (item.status !== ReviewStatus.Approved) {
            Text(formatReviewStatus(item.status))
              .fontSize(12)
              .fontColor(formatReviewColor(item.status))
          }
        }
        .width('100%')

        Text(item.content)
          .fontSize(15)
          .lineHeight(22)
          .fontColor('#3A3A3A')
          .width('100%')

        Row() {
          Text(formatDateTime(item.createdAt))
            .fontSize(12)
            .fontColor('#8B7355')
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
              .fontColor('#8B7355')
              .margin({ left: 10 })
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor('#F2EDE8')
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

        if (this.isReplyingTo(item)) {
          this.InlineReplyBar(item)
        }

        if (this.getThreadReplies(item.id).length > 0) {
          Column({ space: 8 }) {
            Text(`${this.getThreadReplies(item.id).length} 条回复`)
              .fontSize(12)
              .fontColor('#8B7355')
              .alignSelf(ItemAlign.Start)

            ForEach(this.getThreadReplies(item.id), (child: CommentItem) => {
              this.CommentThreadItemView(child, 1)
            }, (child: CommentItem) => this.buildCommentRenderKey(child))
          }
          .width('100%')
          .padding(12)
          .backgroundColor('#F7F2EC')
          .borderRadius(14)
        }
      }
      .width('100%')
      .padding(12)
      .border({
        width: 1,
        color: this.isReplyingTo(item) ? '#C05040' : '#E0D5C6'
      })
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  UploadSection() {
    Column({ space: 10 }) {
      Text('上传参观照片')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')
        .alignSelf(ItemAlign.Start)

      Text('上传的照片会先进入审核，你可以补充拍摄地点和一句简短说明。')
        .fontSize(13)
        .fontColor('#8B7355')
        .alignSelf(ItemAlign.Start)

      TextInput({ placeholder: '拍摄地点', text: this.uploadLocation })
        .height(44)
        .width('100%')
        .backgroundColor('#FFFFFF')
        .borderRadius(10)
        .onChange((value: string) => {
          this.uploadLocation = value;
        })

      TextInput({ placeholder: '简短说明', text: this.uploadDescription })
        .height(44)
        .width('100%')
        .backgroundColor('#FFFFFF')
        .borderRadius(10)
        .onChange((value: string) => {
          this.uploadDescription = value;
        })

      Button(this.isUploadingPhoto ? '正在选择照片...' : '选择照片并上传', { type: ButtonType.Capsule })
        .width('100%')
        .height(44)
        .fontSize(15)
        .backgroundColor('#C05040')
        .fontColor(Color.White)
        .enabled(!this.isUploadingPhoto)
        .onClick(() => {
          this.handleUploadPhoto();
        })
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#F2EDE8')
    .borderRadius(12)
    .margin({ left: 12, right: 12, bottom: 20 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  InfoChip(label: string, value: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor('#8B7355')
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#3A3A3A')
        .margin({ top: 4 })
    }
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

  private async syncFavoriteGroups() {
    if (!this.artifact) {
      return;
    }
    if (!this.isLogin || !this.username) {
      this.favoriteGroups = FAVORITE_GROUPS;
      this.selectedFavoriteGroup = FAVORITE_GROUPS[0];
      this.favoriteDialogGroupName = FAVORITE_GROUPS[0];
      return;
    }
    this.favoriteGroups = await interactionStore.getFavoriteGroups(this.username);
    this.selectedFavoriteGroup = await interactionStore.getFavoriteGroupForArtifact(this.username, this.artifact.id);
    this.favoriteDialogGroupName = this.selectedFavoriteGroup || this.favoriteGroups[0];
  }

  private async handleOpenFavoriteDialog() {
    if (!this.artifact) {
      return;
    }
    if (!this.isLogin || !this.username) {
      this.showToast('请先登录后再收藏');
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    await this.syncFavoriteGroups();
    this.favoriteDialogNewGroupName = '';
    if (!this.favoriteDialogGroupName) {
      this.favoriteDialogGroupName = this.favoriteGroups.length > 0 ? this.favoriteGroups[0] : FAVORITE_GROUPS[0];
    }
    this.showFavoriteDialog = true;
  }

  private closeFavoriteDialog() {
    this.showFavoriteDialog = false;
    this.favoriteDialogNewGroupName = '';
  }

  private async resolveFavoriteDialogGroup(): Promise<string> {
    const newGroupName = this.favoriteDialogNewGroupName.trim();
    if (newGroupName.length > 0) {
      if (this.favoriteGroups.indexOf(newGroupName) === -1) {
        this.favoriteGroups = await interactionStore.addFavoriteGroup(this.username, newGroupName);
      }
      this.favoriteDialogGroupName = newGroupName;
    }
    if (!this.favoriteDialogGroupName) {
      this.favoriteDialogGroupName = this.favoriteGroups.length > 0 ? this.favoriteGroups[0] : FAVORITE_GROUPS[0];
    }
    return this.favoriteDialogGroupName;
  }

  private async handleConfirmFavoriteDialog() {
    if (!this.artifact || !this.username) {
      return;
    }
    const groupName = await this.resolveFavoriteDialogGroup();
    this.selectedFavoriteGroup = groupName;
    if (this.favoriteSummary.active) {
      await interactionStore.moveFavoriteToGroup(this.artifact.id, this.username, groupName);
      this.showToast(`已移动到“${groupName}”`);
    } else {
      this.favoriteSummary = await interactionStore.toggleFavorite(this.artifact, this.username, groupName);
      this.showToast(`已加入“${groupName}”`);
    }
    this.closeFavoriteDialog();
    await this.refreshInteractionState();
  }

  private async handleCancelFavorite() {
    if (!this.artifact || !this.username || !this.favoriteSummary.active) {
      return;
    }
    this.favoriteSummary = await interactionStore.toggleFavorite(this.artifact, this.username, this.selectedFavoriteGroup);
    this.closeFavoriteDialog();
    this.showToast('已取消收藏');
    await this.refreshInteractionState();
  }

  private prepareReply(item: CommentItem) {
    if (!this.isLogin || !this.username) {
      this.showToast('请先登录后再回复评论');
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    this.replyTarget = item;
    this.replyInput = '';
  }

  private cancelReply() {
    this.replyTarget = null;
    this.replyInput = '';
  }

  private async handleToggleCommentLike(item: CommentItem) {
    if (!this.isLogin || !this.username) {
      this.showToast('请先登录后再点赞评论');
      router.pushUrl({ url: 'pages/LoginPage' });
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
    this.showToast(summary.active ? '已点赞评论' : '已取消评论点赞');
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
      '',
      ''
    );
    this.isSubmittingComment = false;
    if (result.ok) {
      this.commentInput = '';
      await this.refreshInteractionState();
      this.scheduleReviewRefresh();
    }
    this.showToast(result.message);
  }

  private async handleSubmitReply() {
    if (!this.artifact || !this.replyTarget) {
      return;
    }
    if (!this.isLogin || !this.username) {
      this.showToast('请先登录后再回复评论');
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
      this.replyInput,
      this.resolveReplyParentId(this.replyTarget),
      this.replyTarget.username
    );
    this.isSubmittingComment = false;
    if (result.ok) {
      this.cancelReply();
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
    await interactionStore.addUpload({
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

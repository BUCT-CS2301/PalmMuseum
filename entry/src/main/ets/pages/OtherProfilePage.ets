// pages/OtherProfilePage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import {
  CommentItem,
  FavoriteItem,
  LikeItem,
  PrivacySettings,
  UploadedPhotoItem
} from '../common/models/InteractionModels';
import {
  PublicHomepageData,
  PublicHomepageService,
  PublicUserProfile,
  VisibleConfig
} from '../common/services/PublicHomepageService';
import { formatDateTime } from '../common/utils/InteractionFormatUtil';

@Entry
@Component
export struct OtherProfilePage {
  @State username: string = '';
  @State currentUsername: string = AppStorage.Get('username') as string || '';
  @State isSelf: boolean = false;
  @State isLoading: boolean = true;
  @State avatarLoadFailed: boolean = false;

  @State profile: PublicUserProfile = {
    userId: '',
    username: '',
    nickname: '',
    avatar: '',
    bio: ''
  };

  @State privacy: PrivacySettings = {
    showFavorites: true,
    showLikes: true,
    showComments: true,
    showPhotos: true
  };

  @State visible: VisibleConfig = {
    favorites: true,
    likes: true,
    comments: true,
    uploads: true
  };

  @State favorites: FavoriteItem[] = [];
  @State likes: LikeItem[] = [];
  @State comments: CommentItem[] = [];
  @State photos: UploadedPhotoItem[] = [];

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;

    if (params && params.username) {
      this.username = params.username;
      this.currentUsername = AppStorage.Get('username') as string || '';
      this.isSelf = this.username === this.currentUsername;
      this.loadData();
    } else {
      promptAction.showToast({ message: '用户不存在' });
      router.back();
    }
  }

  build() {
    Column() {
      Row() {
        Text('< 返回')
          .fontSize(14)
          .fontColor('#C05040')
          .onClick(() => {
            router.back();
          })

        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16 })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(60)
            .height(60)
            .color('#C05040')

          Text('正在加载主页...')
            .fontSize(14)
            .fontColor('#8B7355')
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column() {
            this.ProfileHeader()

            Divider()
              .strokeWidth(0.5)
              .color('#E0D5C6')
              .margin({ top: 24, bottom: 4 })

            this.SectionTitle('收藏夹')
            if (!this.visible.favorites && !this.isSelf) {
              this.PrivacyHint('对方设置了收藏夹不可见')
            } else if (this.favorites.length === 0) {
              this.EmptyHint('暂无收藏')
            } else {
              this.FavoriteList()
            }

            this.SectionTitle('点赞')
            if (!this.visible.likes && !this.isSelf) {
              this.PrivacyHint('对方设置了点赞记录不可见')
            } else if (this.likes.length === 0) {
              this.EmptyHint('暂无点赞')
            } else {
              this.LikeList()
            }

            this.SectionTitle('评论')
            if (!this.visible.comments && !this.isSelf) {
              this.PrivacyHint('对方设置了评论不可见')
            } else if (this.comments.length === 0) {
              this.EmptyHint('暂无评论')
            } else {
              this.CommentList()
            }

            this.SectionTitle('上传照片')
            if (!this.visible.uploads && !this.isSelf) {
              this.PrivacyHint('对方设置了照片不可见')
            } else if (this.photos.length === 0) {
              this.EmptyHint('暂无照片')
            } else {
              this.PhotoList()
            }
          }
          .width('100%')
          .padding({ bottom: 24 })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F0E8')
  }

  @Builder
  ProfileHeader() {
    Column() {
      if (this.getAvatarUrl().length > 0 && !this.avatarLoadFailed) {
        Image(this.getAvatarUrl())
          .width(80)
          .height(80)
          .borderRadius(40)
          .objectFit(ImageFit.Cover)
          .backgroundColor('#E0D5C6')
          .alt($r('app.media.startIcon'))
          .onError(() => {
            console.error(`[OtherProfilePage] 头像加载失败 url=${this.getAvatarUrl()}`);
            this.avatarLoadFailed = true;
          })
      } else {
        Stack() {
          Circle({ width: 80, height: 80 })
            .fill('#E0D5C6')

          Text(this.getInitial())
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width(80)
        .height(80)
      }

      Text(this.getDisplayName())
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor('#3A3A3A')
        .margin({ top: 12 })

      if (this.profile.username) {
        Text(`@${this.profile.username}`)
          .fontSize(13)
          .fontColor('#8B7355')
          .margin({ top: 4 })
      }

      if (this.profile.bio) {
        Text(this.profile.bio)
          .fontSize(14)
          .fontColor('#8B7355')
          .margin({ top: 8 })
          .maxLines(3)
      }

      if (this.isSelf) {
        Text('这是你自己的主页，隐私设置不会限制自己查看')
          .fontSize(12)
          .fontColor('#C05040')
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ top: 24 })
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .fontColor('#3A3A3A')
      .alignSelf(ItemAlign.Start)
      .margin({ left: 16, top: 16, bottom: 8 })
  }

  @Builder
  PrivacyHint(hint: string) {
    Text(hint)
      .fontSize(14)
      .fontColor('#8B7355')
      .width('100%')
      .textAlign(TextAlign.Center)
      .margin({ top: 12, bottom: 12 })
  }

  @Builder
  EmptyHint(msg: string) {
    Text(msg)
      .fontSize(14)
      .fontColor('#8B7355')
      .width('100%')
      .textAlign(TextAlign.Center)
      .margin({ top: 12, bottom: 12 })
  }

  @Builder
  FavoriteList() {
    Column({ space: 12 }) {
      ForEach(this.getFavoriteGroupNames(), (groupName: string) => {
        this.FavoriteGroupSection(groupName)
      }, (groupName: string) => groupName)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  FavoriteGroupSection(groupName: string) {
    Column({ space: 8 }) {
      Row() {
        Text(groupName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#8B7355')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#EADFD2')
          .borderRadius(14)

        Blank()

        Text(`${this.getFavoritesByGroup(groupName).length}`)
          .fontSize(12)
          .fontColor('#8B7355')
      }
      .width('100%')

      Column({ space: 12 }) {
        ForEach(this.getFavoritesByGroup(groupName), (item: FavoriteItem) => {
          this.FavoriteRow(item)
        }, (item: FavoriteItem) => `${groupName}-${item.artifactId}`)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  FavoriteRow(item: FavoriteItem) {
    Row() {
      Image(this.getSafeImageUrl(item.imageUrl))
        .width(60)
        .height(60)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)
        .backgroundColor('#E0D5C6')
        .alt($r('app.media.startIcon'))

      Column() {
        Text(item.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#3A3A3A')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`${item.period} · ${item.museum}`)
          .fontSize(12)
          .fontColor('#8B7355')
          .margin({ top: 4 })

        Text(`分组：${item.groupName}`)
          .fontSize(12)
          .fontColor('#8B7355')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12 })
      .layoutWeight(1)

      Text('>')
        .fontSize(16)
        .fontColor('#8B7355')
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F2EDE8')
    .borderRadius(12)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/ArtifactDetailPage',
        params: { id: item.artifactId }
      });
    })
  }

  @Builder
  LikeList() {
    Column({ space: 12 }) {
      ForEach(this.likes, (item: LikeItem) => {
        this.LikeRow(item)
      }, (item: LikeItem) => item.artifactId)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  LikeRow(item: LikeItem) {
    Row() {
      Image(this.getSafeImageUrl(item.imageUrl))
        .width(60)
        .height(60)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)
        .backgroundColor('#E0D5C6')
        .alt($r('app.media.startIcon'))

      Column() {
        Text(item.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#3A3A3A')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`${item.period} · ${item.museum}`)
          .fontSize(12)
          .fontColor('#8B7355')
          .margin({ top: 4 })

        Text(`点赞时间：${formatDateTime(item.likedAt)}`)
          .fontSize(11)
          .fontColor('#8B7355')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F2EDE8')
    .borderRadius(12)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/ArtifactDetailPage',
        params: { id: item.artifactId }
      });
    })
  }

  @Builder
  CommentList() {
    Column({ space: 12 }) {
      ForEach(this.comments, (item: CommentItem) => {
        this.CommentRow(item)
      }, (item: CommentItem) => item.id)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  CommentRow(item: CommentItem) {
    Column({ space: 6 }) {
      Text(item.artifactTitle || `文物 ${item.artifactId}`)
        .fontSize(13)
        .fontColor('#8B7355')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(item.content)
        .fontSize(14)
        .fontColor('#3A3A3A')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(formatDateTime(item.createdAt))
        .fontSize(11)
        .fontColor('#8B7355')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor('#F2EDE8')
    .borderRadius(12)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/ArtifactDetailPage',
        params: { id: item.artifactId }
      });
    })
  }

  @Builder
  PhotoList() {
    Column({ space: 12 }) {
      ForEach(this.photos, (item: UploadedPhotoItem) => {
        this.PhotoRow(item)
      }, (item: UploadedPhotoItem) => item.id)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  PhotoRow(item: UploadedPhotoItem) {
    Row() {
      Image(this.getSafeImageUrl(item.imageUri))
        .width(60)
        .height(60)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)
        .backgroundColor('#E0D5C6')
        .alt($r('app.media.startIcon'))

      Column() {
        Text(item.description || '暂无描述')
          .fontSize(14)
          .fontColor('#3A3A3A')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (item.artifactTitle) {
          Text(`关联文物：${item.artifactTitle}`)
            .fontSize(12)
            .fontColor('#8B7355')
            .margin({ top: 4 })
        }

        Text(formatDateTime(item.createdAt))
          .fontSize(11)
          .fontColor('#8B7355')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F2EDE8')
    .borderRadius(12)
  }

  private async loadData(): Promise<void> {
    this.isLoading = true;

    try {
      const data: PublicHomepageData = await PublicHomepageService.getPublicHomepage(
        this.username,
        this.currentUsername
      );

      this.profile = data.profile;
      this.avatarLoadFailed = false;
      this.privacy = data.privacy;
      this.visible = data.visible;
      this.favorites = data.favorites;
      this.likes = data.likes;
      this.comments = data.comments;
      this.photos = data.uploads;

      console.info(`[OtherProfilePage] 加载主页成功 username=${this.username}`);
    } catch (error) {
      console.error(`[OtherProfilePage] 加载用户主页失败 ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  private getSafeImageUrl(imageUrl: string): ResourceStr {
    if (imageUrl && imageUrl.trim().length > 0) {
      return imageUrl;
    }

    return $r('app.media.startIcon');
  }

  private getDisplayName(): string {
    if (this.profile.nickname && this.profile.nickname.trim().length > 0) {
      return this.profile.nickname;
    }

    if (this.profile.username && this.profile.username.trim().length > 0) {
      return this.profile.username;
    }

    return '掌上博物馆用户';
  }

  private getInitial(): string {
    const name: string = this.getDisplayName();

    if (name.length > 0) {
      return name.charAt(0).toUpperCase();
    }

    return '他';
  }

  private getAvatarUrl(): string {
    if (this.profile.avatar && this.profile.avatar.trim().length > 0) {
      return this.profile.avatar;
    }

    return '';
  }

  private getFavoriteGroupNames(): string[] {
    const groupNames: string[] = [];
    this.favorites.forEach((item: FavoriteItem) => {
      const groupName = item.groupName && item.groupName.trim().length > 0
        ? item.groupName.trim()
        : '默认收藏夹';
      if (groupNames.indexOf(groupName) === -1) {
        groupNames.push(groupName);
      }
    });
    return groupNames;
  }

  private getFavoritesByGroup(groupName: string): FavoriteItem[] {
    return this.favorites.filter((item: FavoriteItem) => {
      const currentGroup = item.groupName && item.groupName.trim().length > 0
        ? item.groupName.trim()
        : '默认收藏夹';
      return currentGroup === groupName;
    });
  }
}

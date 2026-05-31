// pages/OtherProfilePage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { interactionStore } from '../common/store/InteractionStore';
import { UserService, UserProfile } from '../common/services/UserService';
import { PrivacySettings, FavoriteItem, LikeItem, CommentItem, UploadedPhotoItem } from '../common/models/InteractionModels';

@Entry
@Component
export struct OtherProfilePage {
  @State username: string = '';
  @State profile: UserProfile = { username: '', avatar: '', bio: '' };
  @State privacy: PrivacySettings = { showFavorites: true, showLikes: true, showComments: true, showPhotos: true };
  @State favorites: FavoriteItem[] = [];
  @State likes: LikeItem[] = [];
  @State comments: CommentItem[] = [];
  @State photos: UploadedPhotoItem[] = [];
  @State isLoading: boolean = true;
  @State isSelf: boolean = false;
  @State currentUsername: string = AppStorage.Get('username') as string || '';

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params && params.username) {
      this.username = params.username;
      this.isSelf = this.username === this.currentUsername;
      this.loadData();
    } else {
      promptAction.showToast({ message: '用户不存在' });
      router.back();
    }
  }

  async loadData() {
    this.isLoading = true;
    try {
      // 1. 获取用户资料
      this.profile = await UserService.getProfile(this.username);

      // 2. 获取对方的隐私设置
      if (!this.isSelf) {
        this.privacy = await interactionStore.getPrivacy(this.username);
      } else {
        // 自己看自己，全部可见
        this.privacy = { showFavorites: true, showLikes: true, showComments: true, showPhotos: true };
      }

      // 3. 根据隐私设置选择性加载数据
      if (this.isSelf || this.privacy.showFavorites) {
        this.favorites = await interactionStore.getFavorites(this.username);
      }
      if (this.isSelf || this.privacy.showLikes) {
        this.likes = await interactionStore.getLikes(this.username);
      }
      if (this.isSelf || this.privacy.showComments) {
        this.comments = await interactionStore.getUserComments(this.username);
      }
      if (this.isSelf || this.privacy.showPhotos) {
        this.photos = await interactionStore.getUploads(this.username);
      }
    } catch (error) {
      console.error('加载用户主页失败', JSON.stringify(error));
      promptAction.showToast({ message: '加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      if (this.isLoading) {
        LoadingProgress().width(60).height(60).color('#C05040')
      } else {
        // 头部信息（头像、用户名、简介）
        Column() {
          if (this.profile.avatar) {
            Image(this.profile.avatar)
              .width(80).height(80).borderRadius(40).objectFit(ImageFit.Cover)
          } else {
            Circle({ width: 80, height: 80 })
              .fill('#E0D5C6')
          }
          Text(this.profile.username)
            .fontSize(20).fontWeight(FontWeight.Medium).fontColor('#3A3A3A').margin({ top: 12 })
          if (this.profile.bio) {
            Text(this.profile.bio)
              .fontSize(14).fontColor('#8B7355').margin({ top: 8 }).maxLines(3)
          }
        }
        .width('100%').alignItems(HorizontalAlign.Center).margin({ top: 40 })

        Divider().strokeWidth(0.5).color('#E0D5C6').margin({ top: 24 })

        // 收藏夹
        this.SectionTitle('收藏夹')
        if (!this.privacy.showFavorites && !this.isSelf) {
          this.PrivacyHint('对方设置了收藏夹不可见')
        } else if (this.favorites.length === 0) {
          this.EmptyHint('暂无收藏')
        } else {
          this.FavoriteList()
        }

        // 点赞
        this.SectionTitle('点赞')
        if (!this.privacy.showLikes && !this.isSelf) {
          this.PrivacyHint('对方设置了点赞记录不可见')
        } else if (this.likes.length === 0) {
          this.EmptyHint('暂无点赞')
        } else {
          this.LikeList()
        }

        // 评论（可选，根据需要启用）
        this.SectionTitle('评论')
        if (!this.privacy.showComments && !this.isSelf) {
          this.PrivacyHint('对方设置了评论不可见')
        } else if (this.comments.length === 0) {
          this.EmptyHint('暂无评论')
        } else {
          this.CommentList()
        }

        // 照片（可选）
        this.SectionTitle('上传照片')
        if (!this.privacy.showPhotos && !this.isSelf) {
          this.PrivacyHint('对方设置了照片不可见')
        } else if (this.photos.length === 0) {
          this.EmptyHint('暂无照片')
        } else {
          this.PhotoList()
        }
      }
    }
    .width('100%').height('100%').backgroundColor('#F5F0E8')
  }

  @Builder SectionTitle(title: string) {
    Text(title)
      .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#3A3A3A')
      .alignSelf(ItemAlign.Start)
      .margin({ left: 16, top: 16, bottom: 8 })
  }

  @Builder PrivacyHint(hint: string) {
    Text(hint)
      .fontSize(14).fontColor('#8B7355')
      .width('100%').textAlign(TextAlign.Center)
      .margin({ top: 12, bottom: 12 })
  }

  @Builder EmptyHint(msg: string) {
    Text(msg)
      .fontSize(14).fontColor('#8B7355')
      .width('100%').textAlign(TextAlign.Center)
      .margin({ top: 12, bottom: 12 })
  }

  // 收藏列表（与之前类似，可抽取成 Builder 或复用）
  @Builder FavoriteList() {
    List({ space: 12 }) {
      ForEach(this.favorites, (item: FavoriteItem) => {
        ListItem() { this.FavoriteRow(item) }
      }, (item: FavoriteItem) => item.artifactId)
    }
    .padding({ left: 16, right: 16 })
  }

  @Builder FavoriteRow(item: FavoriteItem) {
    Row() {
      Image(item.imageUrl).width(60).height(60).borderRadius(8).backgroundColor('#F2EDE8')
      Column() {
        Text(item.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#3A3A3A')
        Text(`${item.period} · ${item.museum}`).fontSize(12).fontColor('#8B7355')
      }.alignItems(HorizontalAlign.Start).padding({ left: 12 })
      Blank()
      Text('>').fontColor('#8B7355')
    }
    .width('100%').padding(12).backgroundColor('#F2EDE8').borderRadius(12)
    .onClick(() => router.pushUrl({ url: 'pages/ArtifactDetailPage', params: { id: item.artifactId } }))
  }

  @Builder LikeList() {
    List({ space: 12 }) {
      ForEach(this.likes, (item: LikeItem) => {
        ListItem() { this.LikeRow(item) }
      }, (item: LikeItem) => item.artifactId)
    }
    .padding({ left: 16, right: 16 })
  }

  @Builder LikeRow(item: LikeItem) {
    Row() {
      Image(item.imageUrl).width(60).height(60).borderRadius(8).backgroundColor('#F2EDE8')
      Column() {
        Text(item.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#3A3A3A')
        Text(`${item.period} · ${item.museum}`).fontSize(12).fontColor('#8B7355')
      }.alignItems(HorizontalAlign.Start).padding({ left: 12 })
      Blank()
      Text(item.likedAt).fontSize(11).fontColor('#8B7355')
    }
    .width('100%').padding(12).backgroundColor('#F2EDE8').borderRadius(12)
    .onClick(() => router.pushUrl({ url: 'pages/ArtifactDetailPage', params: { id: item.artifactId } }))
  }

  // 评论和照片列表可以类似构建，先用空状态占位
  @Builder CommentList() {
    List({ space: 12 }) {
      ForEach(this.comments, (item: CommentItem) => {
        ListItem() {
          Row() {
            Text(item.content).fontSize(14).fontColor('#3A3A3A').maxLines(2)
          }
          .width('100%').padding(12).backgroundColor('#F2EDE8').borderRadius(12)
        }
      }, (item: CommentItem) => item.id)
    }
    .padding({ left: 16, right: 16 })
  }

  @Builder PhotoList() {
    List({ space: 12 }) {
      ForEach(this.photos, (item: UploadedPhotoItem) => {
        ListItem() {
          Row() {
            Image(item.imageUri).width(60).height(60).borderRadius(8).backgroundColor('#F2EDE8')
            Text(item.description).fontSize(14).fontColor('#3A3A3A').maxLines(2).padding({ left: 12 })
          }
          .width('100%').padding(12).backgroundColor('#F2EDE8').borderRadius(12)
        }
      }, (item: UploadedPhotoItem) => item.id)
    }
    .padding({ left: 16, right: 16 })
  }
}
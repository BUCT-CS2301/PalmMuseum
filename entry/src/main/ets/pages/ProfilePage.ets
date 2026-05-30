// pages/ProfilePage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { interactionStore } from '../common/store/InteractionStore';
import { UserService, UserProfile } from '../common/services/UserService';
import { UserInteractionStats } from '../common/models/InteractionModels';

@Entry
@Component
export struct ProfilePage {
  @StorageLink('isLogin') isLogin: boolean = false;
  @StorageLink('username') username: string = '';
  @StorageLink('interactionVersion') @Watch('onInteractionVersionChange') interactionVersion: number = 0;
  @StorageLink('profileLikes') profileLikes: number = 0;
  @StorageLink('profileFavorites') profileFavorites: number = 0;
  @StorageLink('profileComments') profileComments: number = 0;
  @StorageLink('profilePhotos') profilePhotos: number = 0;

  @State stats: UserInteractionStats = {
    likes: 0,
    favorites: 0,
    comments: 0,
    photos: 0,
    history: 0
  };
  @State profile: UserProfile = { username: '', avatar: '', bio: '' };

  aboutToAppear() {
    this.refreshAll();
  }

  private async refreshAll() {
    await this.refreshStats();
    await this.loadProfile();
  }

  private async refreshStats() {
    if (!this.isLogin || !this.username) {
      this.stats = { likes: 0, favorites: 0, comments: 0, photos: 0, history: 0 };
      this.profileLikes = 0;
      this.profileFavorites = 0;
      this.profileComments = 0;
      this.profilePhotos = 0;
      return;
    }
    this.stats = await interactionStore.getStats(this.username);
    this.profileLikes = this.stats.likes;
    this.profileFavorites = this.stats.favorites;
    this.profileComments = this.stats.comments;
    this.profilePhotos = this.stats.photos;
  }

  private async loadProfile() {
    if (!this.isLogin || !this.username) {
      this.profile = { username: '', avatar: '', bio: '' };
      return;
    }
    this.profile = await UserService.getProfile(this.username);
  }

  private onInteractionVersionChange(): void {
    this.refreshAll();
  }

  build() {
    Column() {
      if (this.isLogin) {
        // 头像与用户名区域
        Column() {
          if (this.profile.avatar) {
            Image(this.profile.avatar)
              .width(80)
              .height(80)
              .borderRadius(40)
              .objectFit(ImageFit.Cover)
              .margin({ top: 28 })
          } else {
            // 默认头像：圆形背景 + 用户名首字
            Stack() {
              Circle({ width: 80, height: 80 })
                .fill('#E0D5C6')
              Text(this.username.charAt(0).toUpperCase())
                .fontSize(32)
                .fontColor('#FFFFFF')
            }
            .width(80)
            .height(80)
            .margin({ top: 28 })
          }

          Text(this.username)
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3A3A3A')
            .margin({ top: 10 })

          if (this.profile.bio) {
            Text(this.profile.bio)
              .fontSize(14)
              .fontColor('#8B7355')
              .margin({ top: 4 })
              .maxLines(2)
          } else {
            Text('个人主页')
              .fontSize(14)
              .fontColor('#8B7355')
              .margin({ top: 4 })
          }

          // 统计数据行
          Row({ space: 24 }) {
            this.StatItem('点赞', this.stats.likes)
            this.StatItem('收藏', this.stats.favorites)
            this.StatItem('评论', this.stats.comments)
            this.StatItem('照片', this.stats.photos)
          }
          .margin({ top: 12, bottom: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        // 菜单卡片
        Column() {
          this.MenuItem('收藏夹', '📦', 'pages/MyFavoritesPage')
          this.MenuItem('浏览记录', '⏰', 'pages/MyHistoryPage')
          this.MenuItem('我的评论', '💬', 'pages/MyCommentsPage')
          this.MenuItem('上传的照片', '📷', 'pages/MyUploadsPage')
          this.MenuItem('设置', '⚙️', 'pages/SettingsPage')   // 改回“设置”，跳转 SettingsPage
          Divider()
            .strokeWidth(0.5)
            .color('#E0D5C6')
          this.MenuItem('退出登录', '🚪', '')
        }
        .width('100%')
        .backgroundColor('#F2EDE8')
        .borderRadius(12)
        .padding({ top: 8, bottom: 8, left: 20, right: 20 })
        .margin({ left: 12, right: 12, top: 18 })
      } else {
        // 未登录状态
        Column({ space: 20 }) {
          Circle({ width: 80, height: 80 })
            .fill('#E0D5C6')
            .margin({ top: 72 })

          Text('未登录')
            .fontSize(18)
            .fontColor('#3A3A3A')

          Button('去登录')
            .width(200)
            .height(44)
            .fontSize(16)
            .fontColor(Color.White)
            .backgroundColor('#C05040')
            .borderRadius(8)
            .onClick(() => {
              router.pushUrl({ url: 'pages/LoginPage' });
            })

          Button('注册账号')
            .width(200)
            .height(44)
            .fontSize(14)
            .backgroundColor(Color.Transparent)
            .fontColor('#C05040')
            .onClick(() => {
              router.pushUrl({ url: 'pages/RegisterPage' });
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F0E8')
    .onAppear(() => {
      this.refreshAll();
    })
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, currentRatio: number) => {
      if (isVisible && currentRatio > 0) {
        this.refreshAll();
      }
    })
  }

  @Builder
  StatItem(label: string, value: number) {
    Column() {
      Text(value.toString())
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')
      Text(label)
        .fontSize(12)
        .fontColor('#8B7355')
    }
  }

  @Builder
  MenuItem(title: string, icon: string, route: string) {
    Row() {
      Text(icon)
        .fontSize(24)
        .margin({ right: 12 })

      Text(title)
        .fontSize(16)
        .fontColor('#3A3A3A')

      Blank()

      Text('>')
        .fontSize(16)
        .fontColor('#8B7355')
    }
    .width('100%')
    .height(50)
    .onClick(() => {
      if (title === '退出登录') {
        this.doLogout();
        return;
      }

      if (!this.isLogin) {
        promptAction.showToast({ message: '请先登录' });
        router.pushUrl({ url: 'pages/LoginPage' });
        return;
      }

      if (route) {
        router.pushUrl({ url: route });
      }
    })
  }

  doLogout() {
    AppStorage.SetOrCreate('isLogin', false);
    AppStorage.SetOrCreate('username', '');
    AppStorage.SetOrCreate('userId', '');
    AppStorage.SetOrCreate('profileLikes', 0);
    AppStorage.SetOrCreate('profileFavorites', 0);
    AppStorage.SetOrCreate('profileComments', 0);
    AppStorage.SetOrCreate('profilePhotos', 0);
    this.refreshAll();
    promptAction.showToast({ message: '已退出登录' });
  }
}
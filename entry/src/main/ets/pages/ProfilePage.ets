// pages/ProfilePage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserService, UserProfile } from '../common/services/UserService';

@Entry
@Component
export struct ProfilePage {
  @StorageLink('isLogin') isLogin: boolean = false;
  @StorageLink('username') username: string = '';
  @StorageLink('interactionVersion') @Watch('onInteractionVersionChange') interactionVersion: number = 0;
  @State profile: UserProfile = { username: '', avatar: '', bio: '' };

  aboutToAppear() {
    this.loadProfile();
  }

  private async loadProfile() {
    if (!this.isLogin || !this.username) {
      this.profile = { username: '', avatar: '', bio: '' };
      return;
    }
    this.profile = await UserService.getProfile(this.username);
    console.info('===== 获取到的用户资料：', JSON.stringify(this.profile));
  }

  private onInteractionVersionChange(): void {
    this.loadProfile();
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
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        // 菜单卡片
        Column() {
          this.MenuItem('收藏夹', '📦', 'pages/MyFavoritesPage')
          this.MenuItem('浏览记录', '⏰', 'pages/MyHistoryPage')
          this.MenuItem('我的点赞', '❤️', 'pages/MyLikesPage')
          this.MenuItem('我的评论', '💬', 'pages/MyCommentsPage')
          this.MenuItem('上传的照片', '📷', 'pages/MyUploadsPage')
          this.MenuItem('设置', '⚙️', 'pages/SettingsPage')
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
      this.loadProfile();
    })
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, currentRatio: number) => {
      if (isVisible && currentRatio > 0) {
        this.loadProfile();
      }
    })
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
    AppStorage.SetOrCreate('token', '');
    AppStorage.SetOrCreate('refreshToken', '');

    this.profile = { username: '', avatar: '', bio: '' };
    promptAction.showToast({ message: '已退出登录' });
  }
}
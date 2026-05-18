// pages/ProfilePage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserInteractionStats } from '../common/models/InteractionModels';
import { interactionStore } from '../common/store/InteractionStore';

@Entry
@Component
export struct ProfilePage {
  @StorageLink('isLogin') isLogin: boolean = false;
  @StorageLink('username') username: string = '';
  @State stats: UserInteractionStats = {
    likes: 0,
    favorites: 0,
    comments: 0,
    photos: 0,
    history: 0
  };

  aboutToAppear() {
    this.refreshStats();
  }

  private async refreshStats() {
    if (!this.isLogin || !this.username) {
      this.stats = { likes: 0, favorites: 0, comments: 0, photos: 0, history: 0 };
      return;
    }
    this.stats = await interactionStore.getStats(this.username);
  }

  build() {
    Column() {
      if (this.isLogin) {
        Column() {
          Circle({ width: 80, height: 80 }).fill('#CCCCCC').margin({ top: 40 })
          Text(this.username).fontSize(20).fontWeight(FontWeight.Medium).margin({ top: 12 })
          Text('个人主页').fontSize(14).fontColor('#666666')

          Row({ space: 16 }) {
            this.StatItem('点赞', this.stats.likes)
            this.StatItem('收藏', this.stats.favorites)
            this.StatItem('评论', this.stats.comments)
            this.StatItem('照片', this.stats.photos)
          }
          .margin({ top: 16 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        Column() {
          this.MenuItem('收藏夹', '📦', 'pages/MyFavoritesPage')
          this.MenuItem('浏览记录', '⏱️', 'pages/MyHistoryPage')
          this.MenuItem('我的评论', '💬', 'pages/MyCommentsPage')
          this.MenuItem('上传的照片', '📷', 'pages/MyUploadsPage')
          this.MenuItem('隐私设置', '🔒', 'pages/PrivacySettingPage')
          Divider()
          this.MenuItem('退出登录', '🚪', '')
        }
        .width('100%')
        .margin({ top: 30 })
        .padding({ left: 20, right: 20 })
      } else {
        Column({ space: 20 }) {
          Circle({ width: 80, height: 80 }).fill('#CCCCCC').margin({ top: 80 })
          Text('未登录').fontSize(18)

          Button('去登录')
            .width(200).height(44).backgroundColor('#007AFF')
            .onClick(() => {
              router.pushUrl({ url: 'pages/LoginPage' });
            })

          Button('注册账号')
            .width(200).height(44).backgroundColor('transparent').fontColor('#007AFF')
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
    .backgroundColor('#F8F8F8')
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, currentRatio: number) => {
      if (isVisible && currentRatio > 0) {
        this.refreshStats();
      }
    })
  }

  @Builder
  StatItem(label: string, count: number) {
    Column() {
      Text(`${count}`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontSize(12)
        .fontColor('#666666')
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  MenuItem(title: string, icon: string, route: string) {
    Row() {
      Text(icon).fontSize(24).margin({ right: 12 })
      Text(title).fontSize(16)
      Blank()
      Text('>').fontSize(16).fontColor('#CCCCCC')
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
    this.refreshStats();
    promptAction.showToast({ message: '已退出登录' });
  }
}
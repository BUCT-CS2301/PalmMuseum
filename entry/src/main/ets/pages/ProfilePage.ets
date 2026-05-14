// pages/ProfilePage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

@Entry
@Component
export struct ProfilePage {
  @StorageLink('isLogin') isLogin: boolean = false;
  @StorageLink('username') username: string = '';

  build() {
    Column() {
      if (this.isLogin) {
        // 已登录状态
        Column() {
          Circle({ width: 80, height: 80 }).fill('#CCCCCC').margin({ top: 40 })
          Text(this.username).fontSize(20).fontWeight(FontWeight.Medium).margin({ top: 12 })
          Text('个人主页').fontSize(14).fontColor('#666666')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        Column() {
          this.MenuItem('收藏夹', '📦')
          this.MenuItem('浏览记录', '⏱️')
          this.MenuItem('我的评论', '💬')
          this.MenuItem('上传的照片', '📷')
          Divider()
          this.MenuItem('退出登录', '🚪')
        }
        .width('100%')
        .margin({ top: 30 })
        .padding({ left: 20, right: 20 })
      } else {
        // 未登录状态
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
  }

  @Builder
  MenuItem(title: string, icon: string) {
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
      } else {
        promptAction.showToast({ message: '功能开发中' });
      }
    })
  }

  doLogout() {
    AppStorage.SetOrCreate('isLogin', false);
    AppStorage.SetOrCreate('username', '');
    promptAction.showToast({ message: '已退出登录' });
  }
}
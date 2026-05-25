// pages/SettingsPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

@Entry
@Component
export struct SettingsPage {
  @StorageLink('isLogin') isLogin: boolean = false;

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('< 返回')
          .fontSize(14)
          .fontColor('#007AFF')
          .onClick(() => router.back())
        Blank()
      }
      .width('100%')
      .padding(16)

      Text('设置')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: 16, bottom: 24 })

      // 菜单列表
      List({ space: 12 }) {
        // 编辑个人资料
        ListItem() {
          this.SettingMenuItem('编辑个人资料', '✏️', () => {
            router.pushUrl({ url: 'pages/EditProfilePage' });
          })
        }

        // 修改密码
        ListItem() {
          this.SettingMenuItem('修改密码', '🔑', () => {
            router.pushUrl({ url: 'pages/ChangePasswordPage' });
          })
        }

        // 隐私设置
        ListItem() {
          this.SettingMenuItem('隐私设置', '🔒', () => {
            router.pushUrl({ url: 'pages/PrivacySettingPage' });
          })
        }

        // 预留其他设置项（可自行添加）
        ListItem() {
          Row() {
            Text('账号安全')
              .fontSize(16)
              .fontColor('#CCCCCC')
            Blank()
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
        }
      }
      .padding({ left: 16, right: 16 })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F8F8')
  }

  @Builder
  SettingMenuItem(title: string, icon: string, action: () => void) {
    Row() {
      Text(icon)
        .fontSize(24)
        .margin({ right: 12 })

      Text(title)
        .fontSize(16)

      Blank()

      Text('>')
        .fontSize(18)
        .fontColor('#CCCCCC')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .onClick(() => {
      if (!this.isLogin) {
        promptAction.showToast({ message: '请先登录' });
        return;
      }
      action();
    })
  }
}
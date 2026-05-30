// pages/LoginPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import preferences from '@ohos.data.preferences';

let prefs: preferences.Preferences | null = null;

async function getPrefs(context: Context) {
  if (!prefs) {
    prefs = await preferences.getPreferences(context, 'PalmMuseumPrefs');
  }
  return prefs;
}

@Entry
@Component
export struct LoginPage {
  @State username: string = '';
  @State password: string = '';
  @State isLoading: boolean = false;

  build() {
    Column() {
      Text('欢迎登录')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')
        .margin({ top: 60, bottom: 40 })

      TextInput({ placeholder: '请输入用户名/手机号' })
        .width('80%')
        .height(48)
        .fontColor('#3A3A3A')
        .placeholderColor('#999999')
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({ width: 1, color: '#E0D5C6' })
        .margin({ bottom: 16 })
        .onChange((value: string) => {
          this.username = value;
        })

      TextInput({ placeholder: '请输入密码' })
        .width('80%')
        .height(48)
        .type(InputType.Password)
        .fontColor('#3A3A3A')
        .placeholderColor('#999999')
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({ width: 1, color: '#E0D5C6' })
        .margin({ bottom: 24 })
        .onChange((value: string) => {
          this.password = value;
        })

      Button('登 录')
        .width('80%')
        .height(48)
        .fontSize(18)
        .fontColor(Color.White)
        .backgroundColor('#C05040')
        .borderRadius(8)
        .enabled(!this.isLoading)
        .onClick(() => {
          this.doLogin();
        })

      Row() {
        Text('还没有账号？')
          .fontSize(14)
          .fontColor('#8B7355')
        Text('立即注册')
          .fontSize(14)
          .fontColor('#C05040')
          .onClick(() => {
            router.pushUrl({ url: 'pages/RegisterPage' });
          })
      }
      .margin({ top: 20 })

      if (this.isLoading) {
        LoadingProgress()
          .width(40)
          .height(40)
          .color('#C05040')
          .margin({ top: 20 })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F5F0E8')
  }

  async doLogin() {
    if (!this.username || !this.password) {
      promptAction.showToast({ message: '请填写用户名和密码' });
      return;
    }
    this.isLoading = true;

    setTimeout(() => {
      this.isLoading = false;
      AppStorage.SetOrCreate('isLogin', true);
      AppStorage.SetOrCreate('username', this.username);
      promptAction.showToast({ message: '登录成功' });
      router.back();
    }, 1000);
  }
}
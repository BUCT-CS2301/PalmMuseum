// pages/LoginPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserService } from '../common/services/UserService';

@Entry
@Component
export struct LoginPage {
  @State account: string = '';      // 通用账号：用户名/邮箱/手机号
  @State password: string = '';
  @State isLoading: boolean = false;

  build() {
    Column() {
      Text('欢迎登录')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')                     // 统一标题色
        .margin({ top: 60, bottom: 40 })

      TextInput({ placeholder: '用户名/邮箱/手机号' })
        .width('80%')
        .height(48)
        .fontColor('#3A3A3A')
        .placeholderColor('#999999')
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({ width: 1, color: '#E0D5C6' })
        .margin({ bottom: 16 })
        .onChange((value: string) => {
          this.account = value;
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
        .backgroundColor('#C05040')               // 敦煌红主按钮
        .borderRadius(8)
        .enabled(!this.isLoading)
        .onClick(() => {
          this.doLogin();
        })

      // 华为一键登录按钮（保留业务，品牌色适度统一）
      Button('华为账号一键登录')
        .width('80%')
        .height(48)
        .fontSize(16)
        .fontColor(Color.White)
        .backgroundColor('#FF6A00')               // 保留华为品牌橙色
        .borderRadius(8)                          // 统一圆角
        .margin({ top: 12 })
        .enabled(!this.isLoading)
        .onClick(() => {
          this.doHuaweiLogin();
        })

      Row() {
        Text('还没有账号？')
          .fontSize(14)
          .fontColor('#8B7355')                   // 辅助文字色
        Text('立即注册')
          .fontSize(14)
          .fontColor('#C05040')                   // 敦煌红链接色
          .onClick(() => {
            router.pushUrl({ url: 'pages/RegisterPage' });
          })
      }
      .margin({ top: 20 })

      if (this.isLoading) {
        LoadingProgress()
          .width(40)
          .height(40)
          .color('#C05040')                       // 加载指示器配色
          .margin({ top: 20 })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F5F0E8')                   // 统一米白背景
  }

  async doLogin() {
    if (!this.account || !this.password) {
      promptAction.showToast({ message: '请输入账号和密码' });
      return;
    }
    this.isLoading = true;
    const result = await UserService.login(this.account, this.password);
    this.isLoading = false;
    if (result.success) {
      AppStorage.SetOrCreate('isLogin', true);
      AppStorage.SetOrCreate('username', result.username || this.account);
      promptAction.showToast({ message: '登录成功' });
      router.back();
    } else {
      promptAction.showToast({ message: result.message || '登录失败' });
    }
  }

  async doHuaweiLogin() {
    this.isLoading = true;
    const result = await UserService.huaweiLogin();
    this.isLoading = false;
    if (result.success) {
      AppStorage.SetOrCreate('isLogin', true);
      AppStorage.SetOrCreate('username', result.username || '');
      promptAction.showToast({ message: '华为账号登录成功' });
      router.back();
    } else {
      promptAction.showToast({ message: result.message || '华为登录失败' });
    }
  }
}
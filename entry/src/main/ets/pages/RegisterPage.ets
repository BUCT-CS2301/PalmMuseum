// pages/RegisterPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import preferences from '@ohos.data.preferences';

@Entry
@Component
export struct RegisterPage {
  @State username: string = '';
  @State password: string = '';
  @State confirmPwd: string = '';

  build() {
    Column() {
      Text('注册账号')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 60, bottom: 40 })

      TextInput({ placeholder: '用户名/手机号' })
        .width('80%')
        .height(48)
        .margin({ bottom: 16 })
        .onChange((val: string) => this.username = val)

      TextInput({ placeholder: '密码' })
        .width('80%')
        .height(48)
        .type(InputType.Password)
        .margin({ bottom: 16 })
        .onChange((val: string) => this.password = val)

      TextInput({ placeholder: '确认密码' })
        .width('80%')
        .height(48)
        .type(InputType.Password)
        .margin({ bottom: 24 })
        .onChange((val: string) => this.confirmPwd = val)

      Button('注 册')
        .width('80%')
        .height(48)
        .backgroundColor('#28A745')
        .onClick(() => {
          this.doRegister();
        })

      Button('已有账号？去登录')
        .width('80%')
        .height(48)
        .backgroundColor('transparent')
        .fontColor('#007AFF')
        .margin({ top: 12 })
        .onClick(() => {
          router.back();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }

  async doRegister() {
    if (!this.username || !this.password) {
      promptAction.showToast({ message: '请填写完整信息' });
      return;
    }
    if (this.password !== this.confirmPwd) {
      promptAction.showToast({ message: '两次密码不一致' });
      return;
    }
    AppStorage.SetOrCreate('isLogin', true);
    AppStorage.SetOrCreate('username', this.username);
    promptAction.showToast({ message: '注册成功，已自动登录' });
    router.back();
  }
}
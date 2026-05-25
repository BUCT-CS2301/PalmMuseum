// pages/RegisterPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserService, RegisterType } from '../common/services/UserService';

@Entry
@Component
export struct RegisterPage {
  @State username: string = '';
  @State password: string = '';
  @State confirmPwd: string = '';
  @State registerType: RegisterType = 'phone';
  @State accountValue: string = '';
  @State isLoading: boolean = false;
  @State typeOptions: string[] = ['手机号注册', '邮箱注册'];

  build() {
    Column() {
      Text('注册账号')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 60, bottom: 40 })

      // 类型选择按钮
      Row() {
        ForEach(this.typeOptions, (item: string, index: number) => {
          Button(item)
            .fontSize(14)
            .height(36)
            .layoutWeight(1)
            .margin({ left: index === 0 ? 0 : 8 })
            .backgroundColor(this.registerType === (index === 0 ? 'phone' : 'email') ? '#007AFF' : '#E0E0E0')
            .fontColor(this.registerType === (index === 0 ? 'phone' : 'email') ? '#FFFFFF' : '#333333')
            .onClick(() => {
              this.registerType = index === 0 ? 'phone' : 'email';
              this.accountValue = '';
            })
        })
      }
      .width('80%')
      .margin({ bottom: 16 })

      // 根据类型显示输入框
      if (this.registerType === 'phone') {
        TextInput({ placeholder: '请输入手机号', text: this.accountValue })
          .type(InputType.PhoneNumber)
          .maxLength(11)
          .width('80%')
          .height(48)
          .margin({ bottom: 16 })
          .onChange((value: string) => { this.accountValue = value; })
      } else {
        TextInput({ placeholder: '请输入邮箱地址', text: this.accountValue })
          .type(InputType.Email)
          .width('80%')
          .height(48)
          .margin({ bottom: 16 })
          .onChange((value: string) => { this.accountValue = value; })
      }

      TextInput({ placeholder: '设置用户名' })
        .width('80%')
        .height(48)
        .margin({ bottom: 16 })
        .onChange((val: string) => this.username = val)

      TextInput({ placeholder: '设置密码' })
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
        .enabled(!this.isLoading)
        .onClick(() => { this.doRegister(); })

      Button('已有账号？去登录')
        .width('80%')
        .height(48)
        .backgroundColor('transparent')
        .fontColor('#007AFF')
        .margin({ top: 12 })
        .onClick(() => {
          router.back();
        })

      if (this.isLoading) {
        LoadingProgress()
          .width(40)
          .height(40)
          .margin({ top: 20 });
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }

  async doRegister() {
    if (!this.username || !this.password || !this.accountValue) {
      promptAction.showToast({ message: '请填写完整信息' });
      return;
    }
    if (this.password !== this.confirmPwd) {
      promptAction.showToast({ message: '两次密码不一致' });
      return;
    }
    if (this.username.length < 3) {
      promptAction.showToast({ message: '用户名至少3个字符' });
      return;
    }
    if (this.password.length < 4) {
      promptAction.showToast({ message: '密码至少4位' });
      return;
    }

    if (this.registerType === 'phone') {
      if (!/^1[3-9]\d{9}$/.test(this.accountValue)) {
        promptAction.showToast({ message: '请输入正确的手机号' });
        return;
      }
    } else {
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.accountValue)) {
        promptAction.showToast({ message: '请输入正确的邮箱地址' });
        return;
      }
    }

    this.isLoading = true;
    const result = await UserService.register(
      this.username,
      this.password,
      this.registerType,
      this.accountValue
    );
    this.isLoading = false;
    if (result.success) {
      AppStorage.SetOrCreate('isLogin', true);
      AppStorage.SetOrCreate('username', this.username);
      promptAction.showToast({ message: '注册成功，已自动登录' });
      router.back();
    } else {
      promptAction.showToast({ message: result.message || '注册失败' });
    }
  }
}
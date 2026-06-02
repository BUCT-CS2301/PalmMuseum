// pages/RegisterPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserService, RegisterType, RegisterResult } from '../common/services/UserService';

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
      Scroll() {
        Column() {
          Text('注册账号')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3A3A3A')
            .margin({ top: 54, bottom: 10 })

          Text('创建账号后即可登录掌上博物馆')
            .fontSize(13)
            .fontColor('#8B7355')
            .margin({ bottom: 28 })

          Column() {
            Row() {
              ForEach(this.typeOptions, (item: string, index: number) => {
                Button(item)
                  .fontSize(14)
                  .height(38)
                  .layoutWeight(1)
                  .margin({ left: index === 0 ? 0 : 8 })
                  .backgroundColor(this.registerType === (index === 0 ? 'phone' : 'email') ? '#C05040' : '#F2EDE8')
                  .fontColor(this.registerType === (index === 0 ? 'phone' : 'email') ? Color.White : '#3A3A3A')
                  .borderRadius(19)
                  .onClick(() => {
                    this.registerType = index === 0 ? 'phone' : 'email';
                    this.accountValue = '';
                  })
              })
            }
            .width('100%')
            .margin({ bottom: 16 })

            if (this.registerType === 'phone') {
              TextInput({ placeholder: '请输入手机号', text: this.accountValue })
                .type(InputType.PhoneNumber)
                .maxLength(11)
                .width('100%')
                .height(50)
                .fontSize(15)
                .fontColor('#3A3A3A')
                .placeholderColor('#999999')
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .border({ width: 1, color: '#E0D5C6' })
                .padding({ left: 14, right: 14 })
                .margin({ bottom: 14 })
                .onChange((value: string) => {
                  this.accountValue = value;
                })
            } else {
              TextInput({ placeholder: '请输入邮箱地址', text: this.accountValue })
                .type(InputType.Email)
                .width('100%')
                .height(50)
                .fontSize(15)
                .fontColor('#3A3A3A')
                .placeholderColor('#999999')
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .border({ width: 1, color: '#E0D5C6' })
                .padding({ left: 14, right: 14 })
                .margin({ bottom: 14 })
                .onChange((value: string) => {
                  this.accountValue = value;
                })
            }

            TextInput({ placeholder: '设置用户名', text: this.username })
              .width('100%')
              .height(50)
              .fontSize(15)
              .fontColor('#3A3A3A')
              .placeholderColor('#999999')
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .border({ width: 1, color: '#E0D5C6' })
              .padding({ left: 14, right: 14 })
              .margin({ bottom: 14 })
              .onChange((val: string) => {
                this.username = val;
              })

            TextInput({ placeholder: '设置密码', text: this.password })
              .width('100%')
              .height(50)
              .type(InputType.Password)
              .fontSize(15)
              .fontColor('#3A3A3A')
              .placeholderColor('#999999')
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .border({ width: 1, color: '#E0D5C6' })
              .padding({ left: 14, right: 14 })
              .margin({ bottom: 14 })
              .onChange((val: string) => {
                this.password = val;
              })

            TextInput({ placeholder: '确认密码', text: this.confirmPwd })
              .width('100%')
              .height(50)
              .type(InputType.Password)
              .fontSize(15)
              .fontColor('#3A3A3A')
              .placeholderColor('#999999')
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .border({ width: 1, color: '#E0D5C6' })
              .padding({ left: 14, right: 14 })
              .margin({ bottom: 22 })
              .onChange((val: string) => {
                this.confirmPwd = val;
              })

            Button(this.isLoading ? '注册中...' : '注 册')
              .width('100%')
              .height(50)
              .fontSize(17)
              .fontColor(Color.White)
              .backgroundColor('#C05040')
              .borderRadius(25)
              .enabled(!this.isLoading)
              .onClick(() => {
                this.doRegister();
              })

            Button('已有账号？去登录')
              .width('100%')
              .height(44)
              .fontSize(14)
              .backgroundColor(Color.Transparent)
              .fontColor('#C05040')
              .margin({ top: 10 })
              .onClick(() => {
                router.back();
              })
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 20, bottom: 16 })
          .backgroundColor('#F2EDE8')
          .borderRadius(18)

          if (this.isLoading) {
            LoadingProgress()
              .width(36)
              .height(36)
              .color('#C05040')
              .margin({ top: 18 })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 24, right: 24, bottom: 28 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F0E8')
  }

  async doRegister(): Promise<void> {
    if (this.isLoading) {
      return;
    }

    if (!this.username.trim() || !this.password || !this.confirmPwd || !this.accountValue.trim()) {
      promptAction.showToast({ message: '请填写完整信息' });
      return;
    }

    if (this.password !== this.confirmPwd) {
      promptAction.showToast({ message: '两次密码不一致' });
      return;
    }

    if (this.username.trim().length < 3) {
      promptAction.showToast({ message: '用户名至少3个字符' });
      return;
    }

    if (this.password.length < 4) {
      promptAction.showToast({ message: '密码至少4位' });
      return;
    }

    if (this.registerType === 'phone') {
      if (!/^1[3-9]\d{9}$/.test(this.accountValue.trim())) {
        promptAction.showToast({ message: '请输入正确的手机号' });
        return;
      }
    } else {
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.accountValue.trim())) {
        promptAction.showToast({ message: '请输入正确的邮箱地址' });
        return;
      }
    }

    this.isLoading = true;

    try {
      const result: RegisterResult = await UserService.register(
        this.username.trim(),
        this.password,
        this.registerType,
        this.accountValue.trim()
      );

      if (result.success) {
        promptAction.showToast({ message: '注册成功，请登录' });

        this.username = '';
        this.password = '';
        this.confirmPwd = '';
        this.accountValue = '';

        router.back();
        return;
      }

      promptAction.showToast({ message: result.message || '注册失败' });
    } catch (error) {
      console.error(`[RegisterPage] 注册异常 ${JSON.stringify(error)}`);
      const err = error as Error;
      promptAction.showToast({ message: err.message || '注册失败，请稍后重试' });
    } finally {
      this.isLoading = false;
    }
  }
}
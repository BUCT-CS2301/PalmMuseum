// pages/LoginPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserService } from '../common/services/UserService';

@Entry
@Component
export struct LoginPage {
  @State account: string = '';
  @State password: string = '';
  @State isLoading: boolean = false;
  @State showPassword: boolean = false;

  build() {
    Column() {
      Scroll() {
        Column() {
          this.HeaderArea()

          this.LoginCard()

          this.RegisterLink()

          this.FooterTip()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 22, right: 22, top: 40, bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F0E8')
  }

  @Builder
  HeaderArea() {
    Column() {
      Stack() {
        Circle({ width: 82, height: 82 })
          .fill('#E0D5C6')

        Text('博')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(82)
      .height(82)
      .margin({ bottom: 18 })

      Text('欢迎登录')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')

      Text('登录后可同步收藏、点赞、评论和个人设置')
        .fontSize(13)
        .fontColor('#8B7355')
        .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ bottom: 28 })
  }

  @Builder
  LoginCard() {
    Column() {
      Column({ space: 14 }) {
        this.AccountInput()
        this.PasswordInput()
      }
      .width('100%')

      Button(this.isLoading ? '登录中...' : '登 录')
        .width('100%')
        .height(52)
        .fontSize(18)
        .fontColor(Color.White)
        .backgroundColor('#C05040')
        .borderRadius(26)
        .margin({ top: 24 })
        .enabled(!this.isLoading)
        .onClick(() => {
          this.doLogin();
        })

      Button('华为账号一键登录')
        .width('100%')
        .height(50)
        .fontSize(16)
        .fontColor(Color.White)
        .backgroundColor('#FF6A00')
        .borderRadius(25)
        .margin({ top: 12 })
        .enabled(!this.isLoading)
        .onClick(() => {
          this.doHuaweiLogin();
        })

      if (this.isLoading) {
        LoadingProgress()
          .width(34)
          .height(34)
          .color('#C05040')
          .margin({ top: 18 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 20, bottom: 20 })
    .backgroundColor('#F2EDE8')
    .borderRadius(18)
  }

  @Builder
  AccountInput() {
    TextInput({ placeholder: '用户名/邮箱/手机号', text: this.account })
      .width('100%')
      .height(52)
      .fontSize(15)
      .fontColor('#3A3A3A')
      .placeholderColor('#999999')
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .border({ width: 1, color: '#E0D5C6' })
      .padding({ left: 14, right: 14 })
      .onChange((value: string) => {
        this.account = value;
      })
  }

  @Builder
  PasswordInput() {
    Row() {
      TextInput({ placeholder: '请输入密码', text: this.password })
        .layoutWeight(1)
        .height(52)
        .type(this.showPassword ? InputType.Normal : InputType.Password)
        .fontSize(15)
        .fontColor('#3A3A3A')
        .placeholderColor('#999999')
        .backgroundColor('#FFFFFF')
        .padding({ left: 14, right: 8 })
        .onChange((value: string) => {
          this.password = value;
        })

      Text(this.showPassword ? '隐藏' : '显示')
        .fontSize(13)
        .fontColor('#C05040')
        .padding({ left: 8, right: 14 })
        .onClick(() => {
          this.showPassword = !this.showPassword;
        })
    }
    .width('100%')
    .height(52)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E0D5C6' })
  }

  @Builder
  RegisterLink() {
    Row() {
      Text('还没有账号？')
        .fontSize(14)
        .fontColor('#8B7355')

      Text(' 立即注册')
        .fontSize(14)
        .fontColor('#C05040')
        .fontWeight(FontWeight.Medium)
        .onClick(() => {
          router.pushUrl({ url: 'pages/RegisterPage' });
        })
    }
    .margin({ top: 22 })
  }

  @Builder
  FooterTip() {
    Column({ space: 6 }) {
      Text('掌上博物馆')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#8B7355')

      Text('探索海外藏中国文物，收藏你的文化记忆')
        .fontSize(12)
        .fontColor('#A58A6A')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ top: 44 })
  }

  async doLogin(): Promise<void> {
    if (!this.account.trim() || !this.password) {
      promptAction.showToast({ message: '请输入账号和密码' });
      return;
    }

    this.isLoading = true;

    try {
      const result = await UserService.login(this.account.trim(), this.password);
      this.isLoading = false;

      if (result.success) {
        AppStorage.SetOrCreate('isLogin', true);
        AppStorage.SetOrCreate('username', result.username || this.account.trim());
        promptAction.showToast({ message: '登录成功' });
        router.back();
      } else {
        promptAction.showToast({ message: result.message || '登录失败' });
      }
    } catch (error) {
      this.isLoading = false;
      console.error(`[LoginPage] 登录异常 ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '登录失败，请稍后重试' });
    }
  }

  doHuaweiLogin(): void {
    promptAction.showToast({ message: '华为账号登录暂未接入' });
  }
}
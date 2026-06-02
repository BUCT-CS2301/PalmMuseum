// pages/ChangePasswordPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserService, ChangePasswordResult } from '../common/services/UserService';

@Entry
@Component
export struct ChangePasswordPage {
  @State oldPassword: string = '';
  @State newPassword: string = '';
  @State confirmNewPwd: string = '';
  @State isLoading: boolean = false;

  build() {
    Column() {
      Row() {
        Text('<')
          .fontSize(22)
          .fontColor('#C05040')
          .onClick(() => {
            router.back();
          })

        Text('修改密码')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3A3A3A')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text(' ')
          .width(22)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#F5F0E8')

      Column({ space: 16 }) {
        TextInput({ placeholder: '请输入旧密码', text: this.oldPassword })
          .width('100%')
          .height(52)
          .type(InputType.Password)
          .fontSize(15)
          .fontColor('#3A3A3A')
          .placeholderColor('#999999')
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .border({ width: 1, color: '#E0D5C6' })
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.oldPassword = value;
          })

        TextInput({ placeholder: '请输入新密码', text: this.newPassword })
          .width('100%')
          .height(52)
          .type(InputType.Password)
          .fontSize(15)
          .fontColor('#3A3A3A')
          .placeholderColor('#999999')
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .border({ width: 1, color: '#E0D5C6' })
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.newPassword = value;
          })

        TextInput({ placeholder: '请再次输入新密码', text: this.confirmNewPwd })
          .width('100%')
          .height(52)
          .type(InputType.Password)
          .fontSize(15)
          .fontColor('#3A3A3A')
          .placeholderColor('#999999')
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .border({ width: 1, color: '#E0D5C6' })
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.confirmNewPwd = value;
          })

        Button(this.isLoading ? '修改中...' : '确认修改')
          .width('100%')
          .height(52)
          .fontSize(17)
          .fontColor(Color.White)
          .backgroundColor('#C05040')
          .borderRadius(26)
          .enabled(!this.isLoading)
          .onClick(() => {
            this.doChangePassword();
          })
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 24 })

      if (this.isLoading) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color('#C05040')
          .margin({ top: 20 })
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F0E8')
  }

  async doChangePassword(): Promise<void> {
    if (!this.oldPassword || !this.newPassword || !this.confirmNewPwd) {
      promptAction.showToast({ message: '请填写完整信息' });
      return;
    }

    if (this.oldPassword === this.newPassword) {
      promptAction.showToast({ message: '新密码不能与旧密码相同' });
      return;
    }

    if (this.newPassword !== this.confirmNewPwd) {
      promptAction.showToast({ message: '两次新密码不一致' });
      return;
    }

    if (this.newPassword.length < 6) {
      promptAction.showToast({ message: '新密码至少6位' });
      return;
    }

    this.isLoading = true;

    try {
      const result: ChangePasswordResult = await UserService.changePassword(
        this.oldPassword,
        this.newPassword
      );

      this.isLoading = false;

      if (result.success) {
        promptAction.showToast({ message: result.message || '密码修改成功' });
        router.back();
      } else {
        promptAction.showToast({ message: result.message || '密码修改失败' });
      }
    } catch (error) {
      this.isLoading = false;
      console.error(`[ChangePasswordPage] 修改密码异常 ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '密码修改失败，请稍后重试' });
    }
  }
}
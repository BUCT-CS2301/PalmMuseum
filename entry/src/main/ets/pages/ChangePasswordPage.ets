// pages/ChangePasswordPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserService } from '../common/services/UserService';

@Entry
@Component
export struct ChangePasswordPage {
  @StorageLink('username') username: string = '';
  @State oldPassword: string = '';
  @State newPassword: string = '';
  @State confirmNewPwd: string = '';
  @State isLoading: boolean = false;

  build() {
    Column({ space: 16 }) {
      // 导航栏
      Row() {
        Text('< 返回')
          .fontSize(14)
          .fontColor('#007AFF')
          .onClick(() => router.back())
        Blank()
      }
      .width('100%')
      .padding(16)

      Text('修改密码')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: 16, bottom: 24 })

      // 旧密码
      TextInput({ placeholder: '请输入旧密码' })
        .type(InputType.Password)
        .width('90%')
        .height(48)
        .onChange((value: string) => { this.oldPassword = value; })

      // 新密码
      TextInput({ placeholder: '请输入新密码' })
        .type(InputType.Password)
        .width('90%')
        .height(48)
        .onChange((value: string) => { this.newPassword = value; })

      // 确认新密码
      TextInput({ placeholder: '请确认新密码' })
        .type(InputType.Password)
        .width('90%')
        .height(48)
        .onChange((value: string) => { this.confirmNewPwd = value; })

      Button('确认修改')
        .width('90%')
        .height(48)
        .backgroundColor('#007AFF')
        .enabled(!this.isLoading)
        .onClick(() => { this.doChangePassword(); })

      if (this.isLoading) {
        LoadingProgress()
          .width(40)
          .height(40)
          .margin({ top: 20 });
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F8F8')
  }

  async doChangePassword() {
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
    if (this.newPassword.length < 4) {
      promptAction.showToast({ message: '新密码至少4位' });
      return;
    }

    this.isLoading = true;
    const success: boolean = await UserService.changePassword(
      this.username,
      this.oldPassword,
      this.newPassword
    );
    this.isLoading = false;
    if (success) {
      promptAction.showToast({ message: '密码修改成功' });
      router.back();
    } else {
      promptAction.showToast({ message: '旧密码错误或用户不存在' });
    }
  }
}
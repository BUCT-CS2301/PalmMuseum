// pages/EditProfilePage.ets
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { UserService } from '../common/services/UserService';

@Entry
@Component
export struct EditProfilePage {
  @StorageLink('username') username: string = '';
  @State bio: string = '';
  @State avatar: string = '';

  async aboutToAppear() {
    if (this.username) {
      const profile = await UserService.getProfile(this.username);
      this.bio = profile.bio;
      this.avatar = profile.avatar;
    }
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Text('< 返回')
          .fontSize(14)
          .fontColor('#3A3A3A')
          .onClick(() => router.back())
        Blank()
      }
      .width('100%')

      Text('编辑个人资料')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')
        .width('100%')
        .margin({ bottom: 20 })

      TextInput({ placeholder: '个性签名', text: this.bio })
        .width('100%')
        .height(48)
        .fontColor('#3A3A3A')
        .placeholderColor('#999999')
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({ width: 1, color: '#E0D5C6' })
        .onChange((value: string) => { this.bio = value })

      TextInput({ placeholder: '头像链接', text: this.avatar })
        .width('100%')
        .height(48)
        .fontColor('#3A3A3A')
        .placeholderColor('#999999')
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({ width: 1, color: '#E0D5C6' })
        .onChange((value: string) => { this.avatar = value })

      Button('保存')
        .width('100%')
        .height(48)
        .fontSize(18)
        .fontColor(Color.White)
        .backgroundColor('#C05040')
        .borderRadius(8)
        .onClick(async () => {
          if (!this.username) {
            promptAction.showToast({ message: '未登录' });
            return;
          }
          await UserService.updateProfile(this.username, this.avatar, this.bio);
          promptAction.showToast({ message: '保存成功' });
          router.back();
        })
    }
    .width('100%')
    .height('100%')                     // 关键：让背景色铺满全屏
    .padding(16)
    .backgroundColor('#F5F0E8')
  }
}
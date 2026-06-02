// pages/EditProfilePage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { UserService, UserProfile } from '../common/services/UserService';
import { pickSingleImageUri } from '../common/utils/PhotoPickerUtil';

@Entry
@Component
export struct EditProfilePage {
  @StorageLink('username') storageUsername: string = '';

  @State username: string = '';
  @State nickname: string = '';
  @State avatar: string = '';
  @State bio: string = '';
  @State phone: string = '';
  @State email: string = '';
  @State isLoading: boolean = false;
  @State isUploadingAvatar: boolean = false;

  aboutToAppear() {
    this.loadProfile();
  }

  build() {
    Column() {
      Row() {
        Text('< 返回')
          .fontSize(15)
          .fontColor('#C05040')
          .onClick(() => {
            router.back();
          })

        Text('编辑资料')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3A3A3A')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text('保存')
          .fontSize(15)
          .fontColor('#C05040')
          .onClick(() => {
            this.saveProfile();
          })
      }
      .width('100%')
      .height(54)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#F5F0E8')

      Scroll() {
        Column() {
          this.AvatarArea()

          Column({ space: 14 }) {
            Column({ space: 7 }) {
              Text('用户名')
                .fontSize(14)
                .fontColor('#8B7355')
                .width('100%')

              TextInput({ placeholder: '用户名不可修改', text: this.username })
                .width('100%')
                .height(50)
                .fontSize(15)
                .fontColor('#999999')
                .backgroundColor('#F2EDE8')
                .borderRadius(12)
                .border({ width: 1, color: '#E0D5C6' })
                .padding({ left: 14, right: 14 })
                .enabled(false)
            }

            Column({ space: 7 }) {
              Text('昵称')
                .fontSize(14)
                .fontColor('#8B7355')
                .width('100%')

              TextInput({ placeholder: '请输入昵称', text: this.nickname })
                .width('100%')
                .height(50)
                .fontSize(15)
                .fontColor('#3A3A3A')
                .placeholderColor('#B8AFA6')
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .border({ width: 1, color: '#E0D5C6' })
                .padding({ left: 14, right: 14 })
                .onChange((value: string) => {
                  this.nickname = value;
                })
            }

            Column({ space: 7 }) {
              Text('个人简介')
                .fontSize(14)
                .fontColor('#8B7355')
                .width('100%')

              TextInput({ placeholder: '请输入个人简介', text: this.bio })
                .width('100%')
                .height(62)
                .fontSize(15)
                .fontColor('#3A3A3A')
                .placeholderColor('#B8AFA6')
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .border({ width: 1, color: '#E0D5C6' })
                .padding({ left: 14, right: 14 })
                .onChange((value: string) => {
                  this.bio = value;
                })
            }

            Column({ space: 7 }) {
              Text('手机号')
                .fontSize(14)
                .fontColor('#8B7355')
                .width('100%')

              TextInput({ placeholder: '请输入手机号', text: this.phone })
                .width('100%')
                .height(50)
                .fontSize(15)
                .fontColor('#3A3A3A')
                .placeholderColor('#B8AFA6')
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .border({ width: 1, color: '#E0D5C6' })
                .padding({ left: 14, right: 14 })
                .onChange((value: string) => {
                  this.phone = value;
                })
            }

            Column({ space: 7 }) {
              Text('邮箱')
                .fontSize(14)
                .fontColor('#8B7355')
                .width('100%')

              TextInput({ placeholder: '请输入邮箱', text: this.email })
                .width('100%')
                .height(50)
                .fontSize(15)
                .fontColor('#3A3A3A')
                .placeholderColor('#B8AFA6')
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .border({ width: 1, color: '#E0D5C6' })
                .padding({ left: 14, right: 14 })
                .onChange((value: string) => {
                  this.email = value;
                })
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
          .backgroundColor('#F8F3EF')
          .borderRadius(16)
          .margin({ left: 16, right: 16, top: 10 })

          Button(this.isLoading ? '保存中...' : '保存修改')
            .width('92%')
            .height(50)
            .fontSize(16)
            .fontColor(Color.White)
            .backgroundColor('#C05040')
            .borderRadius(25)
            .margin({ top: 22, bottom: 24 })
            .enabled(!this.isLoading && !this.isUploadingAvatar)
            .onClick(() => {
              this.saveProfile();
            })
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F0E8')
  }

  @Builder
  AvatarArea() {
    Column() {
      Stack() {
        if (this.avatar && this.avatar.trim().length > 0) {
          Image(this.avatar)
            .width(92)
            .height(92)
            .borderRadius(46)
            .objectFit(ImageFit.Cover)
            .backgroundColor('#E0D5C6')
            .alt($r('app.media.startIcon'))
        } else {
          Circle({ width: 92, height: 92 })
            .fill('#E0D5C6')

          Text(this.getInitial())
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }

        if (this.isUploadingAvatar) {
          Circle({ width: 92, height: 92 })
            .fill('#66000000')

          LoadingProgress()
            .width(30)
            .height(30)
            .color('#FFFFFF')
        }
      }
      .width(92)
      .height(92)
      .margin({ top: 18, bottom: 8 })
      .onClick(() => {
        this.chooseAndUploadAvatar();
      })

      Text(this.isUploadingAvatar ? '头像上传中...' : '点击更换头像')
        .fontSize(13)
        .fontColor('#8B7355')
        .onClick(() => {
          this.chooseAndUploadAvatar();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: 8 })
  }

  private async loadProfile(): Promise<void> {
    this.isLoading = true;

    try {
      const profile: UserProfile = await UserService.getProfile();

      this.username = profile.username || this.storageUsername || '';
      this.nickname = profile.nickname || profile.username || '';
      this.avatar = profile.avatar || '';
      this.bio = profile.bio || '';
      this.phone = profile.phone || '';
      this.email = profile.email || '';

      console.info(`[EditProfilePage] 加载资料成功 username=${this.username}, nickname=${this.nickname}, bio=${this.bio}, phone=${this.phone}, email=${this.email}`);
    } catch (error) {
      console.error(`[EditProfilePage] 加载资料失败 ${JSON.stringify(error)}`);

      this.username = this.storageUsername || '';
      this.nickname = this.storageUsername || '';
      this.avatar = '';
      this.bio = '';
      this.phone = '';
      this.email = '';

      promptAction.showToast({ message: '加载资料失败' });
    } finally {
      this.isLoading = false;
    }
  }

  private async chooseAndUploadAvatar(): Promise<void> {
    if (this.isUploadingAvatar || this.isLoading) {
      return;
    }

    try {
      const fileUri: string = await pickSingleImageUri();

      if (!fileUri || fileUri.length === 0) {
        return;
      }

      this.isUploadingAvatar = true;

      const context = getContext(this) as common.UIAbilityContext;
      const avatarUrl: string = await UserService.uploadAvatar(context, fileUri);

      if (avatarUrl && avatarUrl.length > 0) {
        this.avatar = avatarUrl;
        AppStorage.SetOrCreate('avatar', avatarUrl);
      }

      promptAction.showToast({ message: '头像上传成功' });
    } catch (error) {
      console.error(`[EditProfilePage] 头像上传失败 ${JSON.stringify(error)}`);
      const err = error as Error;
      promptAction.showToast({ message: err.message || '头像上传失败' });
    } finally {
      this.isUploadingAvatar = false;
    }
  }

  private async saveProfile(): Promise<void> {
    if (this.isLoading) {
      return;
    }

    if (!this.username) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }

    if (!this.nickname.trim()) {
      promptAction.showToast({ message: '昵称不能为空' });
      return;
    }

    this.isLoading = true;

    try {
      const profileToUpdate: UserProfile = {
        objectId: '',
        username: this.username,
        nickname: this.nickname.trim(),
        avatar: this.avatar,
        bio: this.bio.trim(),
        phone: this.phone.trim(),
        email: this.email.trim(),
        roles: [],
        permissions: []
      };

      console.info(`[EditProfilePage] 准备保存资料 ${JSON.stringify(profileToUpdate)}`);

      const updatedProfile: UserProfile = await UserService.updateProfile(profileToUpdate);

      console.info(`[EditProfilePage] 保存资料成功 ${JSON.stringify(updatedProfile)}`);

      this.username = updatedProfile.username || this.username;
      this.nickname = updatedProfile.nickname || this.nickname;
      this.avatar = updatedProfile.avatar || this.avatar;
      this.bio = updatedProfile.bio || '';
      this.phone = updatedProfile.phone || '';
      this.email = updatedProfile.email || '';

      AppStorage.SetOrCreate('username', this.username);
      AppStorage.SetOrCreate('nickname', this.nickname);
      AppStorage.SetOrCreate('avatar', this.avatar);
      AppStorage.SetOrCreate('bio', this.bio);
      AppStorage.SetOrCreate('phone', this.phone);
      AppStorage.SetOrCreate('email', this.email);

      promptAction.showToast({ message: '资料修改成功' });
      router.back();
    } catch (error) {
      console.error(`[EditProfilePage] 保存资料失败 ${JSON.stringify(error)}`);
      const err = error as Error;
      promptAction.showToast({ message: err.message || '资料修改失败' });
    } finally {
      this.isLoading = false;
    }
  }

  private getInitial(): string {
    if (this.nickname && this.nickname.trim().length > 0) {
      return this.nickname.charAt(0).toUpperCase();
    }

    if (this.username && this.username.trim().length > 0) {
      return this.username.charAt(0).toUpperCase();
    }

    return '我';
  }
}
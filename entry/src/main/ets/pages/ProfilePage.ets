// pages/ProfilePage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserService, UserProfile } from '../common/services/UserService';

@Entry
@Component
export struct ProfilePage {
  @StorageLink('isLogin') isLogin: boolean = false;
  @StorageLink('username') storageUsername: string = '';
  @StorageLink('nickname') storageNickname: string = '';
  @StorageLink('avatar') storageAvatar: string = '';
  @StorageLink('bio') storageBio: string = '';

  @State username: string = '';
  @State nickname: string = '';
  @State avatar: string = '';
  @State bio: string = '';
  @State isLoading: boolean = false;
  @State targetUsername: string = '';

  aboutToAppear() {
    this.loadProfile();
  }

  build() {
    Column() {
      if (!this.isLogin) {
        this.NotLoginView()
      } else {
        this.LoggedInView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F0E8')
  }

  @Builder
  NotLoginView() {
    Column() {
      Blank()

      Stack() {
        Circle({ width: 88, height: 88 })
          .fill('#E0D5C6')

        Text('未')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(88)
      .height(88)
      .margin({ bottom: 16 })

      Text('还没有登录')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')
        .margin({ bottom: 8 })

      Text('登录后可以查看收藏、点赞和上传记录')
        .fontSize(14)
        .fontColor('#8B7355')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 26 })

      Button('去登录')
        .width(210)
        .height(46)
        .fontSize(16)
        .fontColor(Color.White)
        .backgroundColor('#C05040')
        .borderRadius(23)
        .onClick(() => {
          router.pushUrl({ url: 'pages/LoginPage' });
        })

      Blank()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
  }

  @Builder
  LoggedInView() {
    Scroll() {
      Column() {
        this.ProfileHeader()

        this.UserSearchBar()

        Column() {
          this.MenuRow('📦', '收藏夹', 'favorites')
          this.MenuRow('⏰', '浏览记录', 'history')
          this.MenuRow('❤️', '我的点赞', 'likes')
          this.MenuRow('💬', '我的评论', 'comments')
          this.MenuRow('📷', '上传的照片', 'uploads')
          this.MenuRow('⚙️', '设置', 'settings')

          Divider()
            .strokeWidth(0.5)
            .color('#E0D5C6')
            .margin({ left: 14, right: 14 })

          this.MenuRow('🚪', '退出登录', 'logout')
        }
        .width('100%')
        .backgroundColor('#F8F3EF')
        .borderRadius(16)
        .margin({ top: 12, left: 12, right: 12, bottom: 24 })
        .padding({ top: 4, bottom: 4 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  ProfileHeader() {
    Column() {
      if (this.getAvatarUrl().length > 0) {
        Image(this.getAvatarUrl())
          .width(86)
          .height(86)
          .borderRadius(43)
          .objectFit(ImageFit.Cover)
          .backgroundColor('#E0D5C6')
          .alt($r('app.media.startIcon'))
          .margin({ top: 22, bottom: 10 })
      } else {
        Stack() {
          Circle({ width: 86, height: 86 })
            .fill('#E0D5C6')

          Text(this.getInitial())
            .fontSize(31)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width(86)
        .height(86)
        .margin({ top: 22, bottom: 10 })
      }

      Text(this.getDisplayName())
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ bottom: 3 })

      Text(`@${this.username || this.storageUsername}`)
        .fontSize(12)
        .fontColor('#8B7355')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ bottom: 8 })

      Text(this.getBioText())
        .fontSize(13)
        .fontColor(this.hasBio() ? '#6F5B45' : '#A8937A')
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('78%')
        .margin({ bottom: 12 })

      Button('编辑资料')
        .width(112)
        .height(34)
        .fontSize(14)
        .fontColor('#C05040')
        .backgroundColor('#FFF8F2')
        .borderRadius(17)
        .border({ width: 1, color: '#C05040' })
        .onClick(() => {
          router.pushUrl({ url: 'pages/EditProfilePage' });
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: 10 })
  }

  @Builder
  UserSearchBar() {
    Column() {
      Row() {
        Text('查看他人主页')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#3A3A3A')
          .layoutWeight(1)

        Text('›')
          .fontSize(18)
          .fontColor('#8B7355')
      }
      .width('100%')
      .margin({ bottom: 10 })

      Row({ space: 8 }) {
        TextInput({ placeholder: '输入用户名', text: this.targetUsername })
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontColor('#3A3A3A')
          .placeholderColor('#B8AFA6')
          .backgroundColor('#FFFFFF')
          .borderRadius(20)
          .border({ width: 1, color: '#E0D5C6' })
          .padding({ left: 14, right: 12 })
          .onChange((value: string) => {
            this.targetUsername = value;
          })

        Button('查看')
          .width(68)
          .height(40)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor('#C05040')
          .borderRadius(20)
          .onClick(() => {
            this.goToOtherProfile();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 13, bottom: 13 })
    .backgroundColor('#F8F3EF')
    .borderRadius(16)
    .margin({ left: 12, right: 12, top: 6 })
  }

  @Builder
  MenuRow(icon: string, title: string, action: string) {
    Row() {
      Text(icon)
        .fontSize(23)
        .width(38)
        .textAlign(TextAlign.Center)

      Text(title)
        .fontSize(17)
        .fontColor('#3A3A3A')
        .layoutWeight(1)
        .margin({ left: 10 })

      Text('>')
        .fontSize(18)
        .fontColor('#8B7355')
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 18 })
    .onClick(() => {
      this.handleMenuClick(action);
    })
  }

  private async loadProfile(): Promise<void> {
    if (!this.isLogin) {
      return;
    }

    this.isLoading = true;

    try {
      const profile: UserProfile = await UserService.getProfile();

      this.username = profile.username || this.storageUsername || '';
      this.nickname = profile.nickname || profile.username || '';
      this.avatar = profile.avatar || '';
      this.bio = profile.bio || '';

      AppStorage.SetOrCreate('username', this.username);
      AppStorage.SetOrCreate('nickname', this.nickname);
      AppStorage.SetOrCreate('avatar', this.avatar);
      AppStorage.SetOrCreate('bio', this.bio);

      console.info(`[ProfilePage] 加载用户信息成功 ${JSON.stringify(profile)}`);
    } catch (error) {
      console.error(`[ProfilePage] 加载用户信息失败 ${JSON.stringify(error)}`);

      this.username = this.storageUsername || '';
      this.nickname = this.storageNickname || this.storageUsername || '';
      this.avatar = this.storageAvatar || '';
      this.bio = this.storageBio || '';

      promptAction.showToast({ message: '用户信息加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  private getDisplayName(): string {
    if (this.nickname && this.nickname.trim().length > 0) {
      return this.nickname;
    }

    if (this.storageNickname && this.storageNickname.trim().length > 0) {
      return this.storageNickname;
    }

    if (this.username && this.username.trim().length > 0) {
      return this.username;
    }

    if (this.storageUsername && this.storageUsername.trim().length > 0) {
      return this.storageUsername;
    }

    return '掌上博物馆用户';
  }

  private getBioText(): string {
    if (this.bio && this.bio.trim().length > 0) {
      return this.bio;
    }

    if (this.storageBio && this.storageBio.trim().length > 0) {
      return this.storageBio;
    }

    return '这个人还没有写简介';
  }

  private hasBio(): boolean {
    if (this.bio && this.bio.trim().length > 0) {
      return true;
    }

    if (this.storageBio && this.storageBio.trim().length > 0) {
      return true;
    }

    return false;
  }

  private getAvatarUrl(): string {
    if (this.avatar && this.avatar.trim().length > 0) {
      return this.avatar;
    }

    if (this.storageAvatar && this.storageAvatar.trim().length > 0) {
      return this.storageAvatar;
    }

    return '';
  }

  private getInitial(): string {
    const name: string = this.getDisplayName();

    if (name.length > 0) {
      return name.charAt(0).toUpperCase();
    }

    return '我';
  }

  private goToOtherProfile(): void {
    const target: string = this.targetUsername.trim();

    if (!target) {
      promptAction.showToast({ message: '请输入用户名' });
      return;
    }

    if (target === this.username || target === this.storageUsername) {
      promptAction.showToast({ message: '这是你自己的主页' });
      return;
    }

    router.pushUrl({
      url: 'pages/OtherProfilePage',
      params: {
        username: target
      }
    });
  }

  private handleMenuClick(action: string): void {
    if (action === 'favorites') {
      router.pushUrl({ url: 'pages/MyFavoritesPage' });
    } else if (action === 'history') {
      router.pushUrl({ url: 'pages/MyHistoryPage' });
    } else if (action === 'likes') {
      router.pushUrl({ url: 'pages/MyLikesPage' });
    } else if (action === 'comments') {
      router.pushUrl({ url: 'pages/MyCommentsPage' });
    } else if (action === 'uploads') {
      router.pushUrl({ url: 'pages/MyUploadsPage' });
    } else if (action === 'settings') {
      router.pushUrl({ url: 'pages/SettingsPage' });
    } else if (action === 'logout') {
      this.logout();
    }
  }

  private logout(): void {
    AppStorage.SetOrCreate('isLogin', false);
    AppStorage.SetOrCreate('token', '');
    AppStorage.SetOrCreate('refreshToken', '');
    AppStorage.SetOrCreate('username', '');
    AppStorage.SetOrCreate('userId', '');
    AppStorage.SetOrCreate('nickname', '');
    AppStorage.SetOrCreate('avatar', '');
    AppStorage.SetOrCreate('bio', '');
    AppStorage.SetOrCreate('phone', '');
    AppStorage.SetOrCreate('email', '');

    this.username = '';
    this.nickname = '';
    this.avatar = '';
    this.bio = '';
    this.targetUsername = '';

    promptAction.showToast({ message: '已退出登录' });
    router.replaceUrl({ url: 'pages/LoginPage' });
  }
}
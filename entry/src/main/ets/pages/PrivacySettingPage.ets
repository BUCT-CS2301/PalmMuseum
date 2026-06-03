// pages/PrivacySettingPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { PrivacySettings } from '../common/models/InteractionModels';
import { PrivacyService } from '../common/services/PrivacyService';

@Entry
@Component
export struct PrivacySettingPage {
  @StorageLink('username') username: string = '';

  @State privacy: PrivacySettings = {
    showFavorites: true,
    showLikes: true,
    showComments: true,
    showPhotos: true
  };

  @State isLoading: boolean = false;
  @State isSaving: boolean = false;
  @State refreshKey: number = 0;

  aboutToAppear() {
    this.loadPrivacy();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 6 }) {
        Row() {
          Text('< 返回')
            .fontSize(14)
            .fontColor('#C05040')
            .onClick(() => {
              router.back();
            })

          Blank()
        }
        .width('100%')

        Text('隐私设置')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3A3A3A')
          .width('100%')

        Text('是否让别人看到你的收藏、点赞、评论和上传内容')
          .fontSize(13)
          .fontColor('#8B7355')
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(38)
            .height(38)
            .color('#C05040')

          Text('正在读取隐私设置...')
            .fontSize(13)
            .fontColor('#8B7355')
            .margin({ top: 10 })
        }
        .width('100%')
        .height(160)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Column({ space: 12 }) {
          if (this.refreshKey >= 0) {
            this.FavoritePrivacyRow()
            this.LikePrivacyRow()
            this.CommentPrivacyRow()
            this.PhotoPrivacyRow()
          }
        }
        .width('100%')
      }

      Text(this.isSaving ? '正在保存设置...' : '设置会实时保存，并同步到后端隐私配置。')
        .fontSize(12)
        .fontColor('#8B7355')
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#F5F0E8')
  }

  @Builder
  FavoritePrivacyRow() {
    Row() {
      Column({ space: 4 }) {
        Text('收藏夹可见')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#3A3A3A')

        Text('关闭后仅自己可见')
          .fontSize(12)
          .fontColor('#8B7355')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: this.privacy.showFavorites })
        .selectedColor('#C05040')
        .onChange((value: boolean) => {
          this.updatePrivacy('favorite', value);
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F2EDE8')
    .borderRadius(12)
  }

  @Builder
  LikePrivacyRow() {
    Row() {
      Column({ space: 4 }) {
        Text('点赞可见')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#3A3A3A')

        Text('关闭后其他用户看不到你的点赞记录')
          .fontSize(12)
          .fontColor('#8B7355')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: this.privacy.showLikes })
        .selectedColor('#C05040')
        .onChange((value: boolean) => {
          this.updatePrivacy('like', value);
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F2EDE8')
    .borderRadius(12)
  }

  @Builder
  CommentPrivacyRow() {
    Row() {
      Column({ space: 4 }) {
        Text('评论可见')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#3A3A3A')

        Text('关闭后主页中不展示公开评论')
          .fontSize(12)
          .fontColor('#8B7355')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: this.privacy.showComments })
        .selectedColor('#C05040')
        .onChange((value: boolean) => {
          this.updatePrivacy('comment', value);
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F2EDE8')
    .borderRadius(12)
  }

  @Builder
  PhotoPrivacyRow() {
    Row() {
      Column({ space: 4 }) {
        Text('上传照片可见')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#3A3A3A')

        Text('关闭后相册内容默认私密')
          .fontSize(12)
          .fontColor('#8B7355')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: this.privacy.showPhotos })
        .selectedColor('#C05040')
        .onChange((value: boolean) => {
          this.updatePrivacy('photo', value);
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F2EDE8')
    .borderRadius(12)
  }

  private async loadPrivacy(): Promise<void> {
    if (!this.username) {
      console.error('[PrivacySettingPage] username 为空，无法读取隐私设置');

      this.privacy = {
        showFavorites: true,
        showLikes: true,
        showComments: true,
        showPhotos: true
      };

      this.refreshKey++;
      return;
    }

    this.isLoading = true;

    try {
      const saved: PrivacySettings = await PrivacyService.getMyPrivacy(this.username);

      this.privacy = {
        showFavorites: saved.showFavorites,
        showLikes: saved.showLikes,
        showComments: saved.showComments,
        showPhotos: saved.showPhotos
      };

      this.refreshKey++;

      console.info(
        `[PrivacySettingPage] 读取隐私设置 username=${this.username}, privacy=${JSON.stringify(this.privacy)}`
      );
    } catch (error) {
      console.error(`[PrivacySettingPage] 读取隐私设置失败 ${JSON.stringify(error)}`);

      this.privacy = {
        showFavorites: true,
        showLikes: true,
        showComments: true,
        showPhotos: true
      };

      this.refreshKey++;
      promptAction.showToast({ message: '读取隐私设置失败，已使用默认设置' });
    } finally {
      this.isLoading = false;
    }
  }

  private async updatePrivacy(key: string, value: boolean): Promise<void> {
    if (this.isLoading) {
      return;
    }

    if (!this.username) {
      promptAction.showToast({ message: '请先登录' });
      console.error('[PrivacySettingPage] username 为空，无法保存隐私设置');
      return;
    }

    const currentValue: boolean = this.getCurrentValue(key);

    // 关键修复：
    // Toggle 初始化或异步刷新时可能触发 onChange。
    // 如果传进来的 value 和当前状态一致，说明不是用户主动改变，不保存、不弹 toast。
    if (currentValue === value) {
      return;
    }

    const oldPrivacy: PrivacySettings = {
      showFavorites: this.privacy.showFavorites,
      showLikes: this.privacy.showLikes,
      showComments: this.privacy.showComments,
      showPhotos: this.privacy.showPhotos
    };

    const nextPrivacy: PrivacySettings = {
      showFavorites: this.privacy.showFavorites,
      showLikes: this.privacy.showLikes,
      showComments: this.privacy.showComments,
      showPhotos: this.privacy.showPhotos
    };

    if (key === 'favorite') {
      nextPrivacy.showFavorites = value;
    } else if (key === 'like') {
      nextPrivacy.showLikes = value;
    } else if (key === 'comment') {
      nextPrivacy.showComments = value;
    } else if (key === 'photo') {
      nextPrivacy.showPhotos = value;
    }

    this.privacy = {
      showFavorites: nextPrivacy.showFavorites,
      showLikes: nextPrivacy.showLikes,
      showComments: nextPrivacy.showComments,
      showPhotos: nextPrivacy.showPhotos
    };

    this.refreshKey++;
    this.isSaving = true;

    try {
      const saved: PrivacySettings = await PrivacyService.updateMyPrivacy(this.username, this.privacy);

      this.privacy = {
        showFavorites: saved.showFavorites,
        showLikes: saved.showLikes,
        showComments: saved.showComments,
        showPhotos: saved.showPhotos
      };

      this.refreshKey++;

      console.info(
        `[PrivacySettingPage] 保存隐私设置 username=${this.username}, privacy=${JSON.stringify(this.privacy)}`
      );

      promptAction.showToast({ message: '设置已更新' });
    } catch (error) {
      console.error(`[PrivacySettingPage] 保存隐私设置失败 ${JSON.stringify(error)}`);

      this.privacy = {
        showFavorites: oldPrivacy.showFavorites,
        showLikes: oldPrivacy.showLikes,
        showComments: oldPrivacy.showComments,
        showPhotos: oldPrivacy.showPhotos
      };

      this.refreshKey++;
      promptAction.showToast({ message: '保存失败，请重试' });
    } finally {
      this.isSaving = false;
    }
  }

  private getCurrentValue(key: string): boolean {
    if (key === 'favorite') {
      return this.privacy.showFavorites;
    }

    if (key === 'like') {
      return this.privacy.showLikes;
    }

    if (key === 'comment') {
      return this.privacy.showComments;
    }

    if (key === 'photo') {
      return this.privacy.showPhotos;
    }

    return true;
  }
}
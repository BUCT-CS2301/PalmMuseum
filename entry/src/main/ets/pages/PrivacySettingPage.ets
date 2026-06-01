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

  // 用于强制刷新 Toggle，避免 Toggle 显示状态不跟随异步读取结果更新
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

      Column({ space: 12 }) {
        if (this.refreshKey >= 0) {
          this.FavoritePrivacyRow()
          this.LikePrivacyRow()
          this.CommentPrivacyRow()
          this.PhotoPrivacyRow()
        }
      }
      .width('100%')

      Text('设置会实时保存，后续接入后端时可直接映射到用户配置接口。')
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
    }
  }

  private async updatePrivacy(key: string, value: boolean): Promise<void> {
    if (!this.username) {
      promptAction.showToast({ message: '请先登录' });
      console.error('[PrivacySettingPage] username 为空，无法保存隐私设置');
      return;
    }

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

    // 先更新页面状态，让开关立即响应
    this.privacy = {
      showFavorites: nextPrivacy.showFavorites,
      showLikes: nextPrivacy.showLikes,
      showComments: nextPrivacy.showComments,
      showPhotos: nextPrivacy.showPhotos
    };

    this.refreshKey++;

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
      promptAction.showToast({ message: '保存失败，请重试' });

      // 保存失败时重新读取，避免页面状态和真实数据不一致
      await this.loadPrivacy();
    }
  }
}
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { DEFAULT_PRIVACY_SETTINGS, PrivacySettings } from '../common/models/InteractionModels';
import { interactionStore } from '../common/store/InteractionStore';

@Entry
@Component
export struct PrivacySettingPage {
  @StorageLink('username') username: string = '';
  @State privacy: PrivacySettings = DEFAULT_PRIVACY_SETTINGS;

  aboutToAppear() {
    this.loadPrivacy();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 6 }) {
        Row() {
          Text('< 返回')
            .fontSize(14)
            .fontColor('#C05040')            // 敦煌红
            .onClick(() => {
              router.back();
            })
          Blank()
        }
        .width('100%')

        Text('隐私设置')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3A3A3A')               // 主文字色
          .width('100%')
        Text('是否让别人看到你的收藏、评论和上传内容')
          .fontSize(13)
          .fontColor('#8B7355')               // 辅助文字色
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 12 }) {
        this.SettingRow('收藏夹可见', '关闭后仅自己可见', this.privacy.showFavorites, 'favorite')
        this.SettingRow('评论可见', '关闭后主页中不展示公开评论', this.privacy.showComments, 'comment')
        this.SettingRow('上传照片可见', '关闭后相册内容默认私密', this.privacy.showPhotos, 'photo')
      }
      .width('100%')

      Text('设置会实时保存到本地，后续接入后端时可直接映射到用户配置接口。')
        .fontSize(12)
        .fontColor('#8B7355')
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#F5F0E8')               // 页面背景米白，与主页一致
  }

  @Builder
  SettingRow(title: string, description: string, isOn: boolean, key: string) {
    Row() {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#3A3A3A')               // 主文字色
        Text(description)
          .fontSize(12)
          .fontColor('#8B7355')               // 辅助文字色
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor('#C05040')             // 敦煌红选中色
        .onChange((value: boolean) => {
          this.updatePrivacy(key, value);
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F2EDE8')               // 暖米色卡片，柔和融入背景
    .borderRadius(18)
  }

  private async loadPrivacy() {
    if (!this.username) {
      this.privacy = DEFAULT_PRIVACY_SETTINGS;
      return;
    }
    this.privacy = await interactionStore.getPrivacy(this.username);
  }

  private async updatePrivacy(key: string, value: boolean) {
    let nextPrivacy: PrivacySettings = {
      showFavorites: this.privacy.showFavorites,
      showComments: this.privacy.showComments,
      showPhotos: this.privacy.showPhotos
    };
    if (key === 'favorite') {
      nextPrivacy.showFavorites = value;
    } else if (key === 'comment') {
      nextPrivacy.showComments = value;
    } else if (key === 'photo') {
      nextPrivacy.showPhotos = value;
    }
    this.privacy = nextPrivacy;
    await interactionStore.savePrivacy(this.username, nextPrivacy);
    promptAction.showToast({ message: '设置已更新' });
  }
}
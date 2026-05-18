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
            .fontColor('#8C5A2B')
            .onClick(() => {
              router.back();
            })
          Blank()
        }
        .width('100%')

        Text('隐私设置')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .width('100%')
        Text('是否让别人看到你的收藏、评论和上传内容')
          .fontSize(13)
          .fontColor('#7A6A58')
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
        .fontColor('#8F8B85')
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#F6F2EC')
  }

  @Builder
  SettingRow(title: string, description: string, isOn: boolean, key: string) {
    Row() {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Text(description)
          .fontSize(12)
          .fontColor('#8D8D8D')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor('#8C5A2B')
        .onChange((value: boolean) => {
          this.updatePrivacy(key, value);
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
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
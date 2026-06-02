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

  @State refreshKey: number = 0;

  aboutToAppear() {
    this.loadPrivacy();
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 6 }) {
        Row() {
          Text('< 杩斿洖')
            .fontSize(14)
            .fontColor('#C05040')
            .onClick(() => {
              router.back();
            })

          Blank()
        }
        .width('100%')

        Text('闅愮璁剧疆')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3A3A3A')
          .width('100%')

        Text('鏄惁璁╁埆浜虹湅鍒颁綘鐨勬敹钘忋€佺偣璧炪€佽瘎璁哄拰涓婁紶鍐呭')
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

      Text('璁剧疆浼氬疄鏃朵繚瀛橈紝宸蹭紭鍏堟帴鍏ュ悗绔殣绉佹帴鍙ｃ€?')
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
        Text('鏀惰棌澶瑰彲瑙?')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#3A3A3A')

        Text('鍏抽棴鍚庝粎鑷繁鍙')
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
        Text('鐐硅禐鍙')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#3A3A3A')

        Text('鍏抽棴鍚庡叾浠栫敤鎴风湅涓嶅埌浣犵殑鐐硅禐璁板綍')
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
        Text('璇勮鍙')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#3A3A3A')

        Text('鍏抽棴鍚庝富椤典腑涓嶅睍绀哄叕寮€璇勮')
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
        Text('涓婁紶鐓х墖鍙')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#3A3A3A')

        Text('鍏抽棴鍚庣浉鍐屽唴瀹归粯璁ょ瀵?')
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
      console.error('[PrivacySettingPage] username 涓虹┖锛屾棤娉曡鍙栭殣绉佽缃?');
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
        `[PrivacySettingPage] 璇诲彇闅愮璁剧疆 username=${this.username}, privacy=${JSON.stringify(this.privacy)}`
      );
    } catch (error) {
      console.error(`[PrivacySettingPage] 璇诲彇闅愮璁剧疆澶辫触 ${JSON.stringify(error)}`);
      this.privacy = {
        showFavorites: true,
        showLikes: true,
        showComments: true,
        showPhotos: true
      };
      this.refreshKey++;
      promptAction.showToast({ message: '璇诲彇闅愮璁剧疆澶辫触锛屽凡浣跨敤榛樿璁剧疆' });
    }
  }

  private async updatePrivacy(key: string, value: boolean): Promise<void> {
    if (!this.username) {
      promptAction.showToast({ message: '璇峰厛鐧诲綍' });
      console.error('[PrivacySettingPage] username 涓虹┖锛屾棤娉曚繚瀛橀殣绉佽缃?');
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
        `[PrivacySettingPage] 淇濆瓨闅愮璁剧疆 username=${this.username}, privacy=${JSON.stringify(this.privacy)}`
      );
      promptAction.showToast({ message: '璁剧疆宸叉洿鏂? });
    } catch (error) {
      console.error(`[PrivacySettingPage] 淇濆瓨闅愮璁剧疆澶辫触 ${JSON.stringify(error)}`);
      promptAction.showToast({ message: '淇濆瓨澶辫触锛岃閲嶈瘯' });
      await this.loadPrivacy();
    }
  }
}

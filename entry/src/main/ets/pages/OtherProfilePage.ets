// pages/OtherProfilePage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { interactionStore } from '../common/store/InteractionStore';
import { UserService, UserProfile } from '../common/services/UserService';
import { PrivacySettings, FavoriteItem } from '../common/models/InteractionModels';

@Entry
@Component
export struct OtherProfilePage {
  @State username: string = '';
  @State profile: UserProfile = { username: '', avatar: '', bio: '' };
  @State favorites: FavoriteItem[] = [];
  @State isLoading: boolean = true;
  @State isSelf: boolean = false;
  @State currentUsername: string = AppStorage.Get('username') as string || '';

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (params && params.username) {
      this.username = params.username;
      this.isSelf = this.username === this.currentUsername;
      this.loadData();
    } else {
      promptAction.showToast({ message: '用户不存在' });
      router.back();
    }
  }

  async loadData() {
    this.isLoading = true;
    try {
      // 1. 获取用户资料（头像、简介）
      this.profile = await UserService.getProfile(this.username);

      // 2. 获取隐私设置
      const privacy: PrivacySettings = await interactionStore.getPrivacy(this.username);

      // 3. 根据隐私设置决定是否展示互动数据
      if (this.isSelf || privacy.showFavorites) {
        this.favorites = await interactionStore.getFavorites(this.username);
      } else {
        this.favorites = [];
      }
      // 同理可添加评论、照片等（按需）
    } catch (error) {
      console.error('加载用户主页失败', JSON.stringify(error));
      promptAction.showToast({ message: '加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      if (this.isLoading) {
        LoadingProgress()
          .width(60)
          .height(60)
          .color('#C05040');                      // 统一加载色
      } else {
        // 头部信息
        Column() {
          // 头像
          if (this.profile.avatar) {
            Image(this.profile.avatar)
              .width(80)
              .height(80)
              .borderRadius(40)
              .objectFit(ImageFit.Cover);
          } else {
            Circle({ width: 80, height: 80 })
              .fill('#E0D5C6');                    // 统一浅米色
          }

          // 用户名
          Text(this.profile.username)
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3A3A3A')                  // 统一主文字色
            .margin({ top: 12 });

          // 个人简介（如果有且未被隐私隐藏）
          if (this.profile.bio) {
            Text(this.profile.bio)
              .fontSize(14)
              .fontColor('#8B7355')                // 统一辅助文字色
              .margin({ top: 8 })
              .maxLines(3);
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ top: 40 });

        Divider()
          .strokeWidth(0.5)
          .color('#E0D5C6')                        // 统一分割线色
          .margin({ top: 24 });

        // 收藏展示
        Text('公开的收藏')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3A3A3A')                    // 统一标题色
          .alignSelf(ItemAlign.Start)
          .margin({ left: 16, top: 16, bottom: 8 });

        if (this.favorites.length === 0) {
          Text('暂无公开收藏')
            .fontColor('#8B7355')                   // 辅助文字色
            .margin({ top: 20 });
        } else {
          List({ space: 12 }) {
            ForEach(this.favorites, (item: FavoriteItem) => {
              ListItem() {
                Row() {
                  Image(item.imageUrl)
                    .width(60)
                    .height(60)
                    .borderRadius(8)
                    .backgroundColor('#F2EDE8')     // 统一卡片背景
                    .objectFit(ImageFit.Cover);

                  Column() {
                    Text(item.title)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#3A3A3A')        // 主文字色
                      .maxLines(1);
                    Text(`${item.period} · ${item.museum}`)
                      .fontSize(12)
                      .fontColor('#8B7355');        // 辅助文字色
                  }
                  .alignItems(HorizontalAlign.Start)
                  .padding({ left: 12 });

                  Blank();

                  Text('>')
                    .fontSize(16)
                    .fontColor('#8B7355');          // 辅助箭头色
                }
                .width('100%')
                .padding(12)
                .backgroundColor('#F2EDE8')         // 统一卡片背景
                .borderRadius(12)
                .onClick(() => {
                  router.pushUrl({
                    url: 'pages/ArtifactDetailPage',
                    params: { id: item.artifactId }
                  });
                });
              }
            }, (item: FavoriteItem) => item.artifactId);
          }
          .padding({ left: 16, right: 16 })
          .layoutWeight(1);
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F0E8');                    // 统一页面背景
  }
}
// Index.ets
import { HomePage } from './HomePage';
import { ProfilePage } from './ProfilePage';
import { DiscoverPage } from './DiscoverPage';
import { ShowPage } from './ShowPage';
import font from '@ohos.font';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  aboutToAppear() {
    font.registerFont({
      familyName: 'myCustomFont',
      familySrc: $rawfile('fahuawenkai.ttf')
    });
  }

  @Builder
  TabBarItem(index: number, label: string, icon: string, selectedIcon: string) {
    Column() {
      Text(this.currentIndex === index ? selectedIcon : icon)
        .fontSize(24)
        .fontColor(this.currentIndex === index ? '#C05040' : '#8B7355')

      Text(label)
        .fontSize(12)
        .fontColor(this.currentIndex === index ? '#C05040' : '#8B7355')
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Regular)
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.currentIndex = index;

      if (index === 2) {
        AppStorage.SetOrCreate('interactionVersion', Date.now());
      }
    })
  }

  build() {
    Tabs({ index: this.currentIndex }) {
      TabContent() {
        ShowPage()
      }
      .tabBar(this.TabBarItem(0, '首页', '🏛️', '🏛️'))

      TabContent() {
        HomePage()
      }
      .tabBar(this.TabBarItem(1, '文物', '🏺', '🏺'))

      TabContent() {
        DiscoverPage()
      }
      .tabBar(this.TabBarItem(2, '发现', '🔍', '🔍'))

      TabContent() {
        ProfilePage()
      }
      .tabBar(this.TabBarItem(3, '我的', '📜', '📜'))
    }
    .barMode(BarMode.Fixed)
    .barPosition(BarPosition.End)
    .onChange((index: number) => {
      this.currentIndex = index;

      if (index === 2) {
        AppStorage.SetOrCreate('interactionVersion', Date.now());
      }
    })
    .scrollable(false)
    .animationDuration(0)
    .barBackgroundColor('#F5F0E8')
    .divider({
      strokeWidth: 0.5,
      color: '#E0D5C6'
    })
    .width('100%')
    .height('100%')
  }
}
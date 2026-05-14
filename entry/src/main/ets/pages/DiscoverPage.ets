@Entry
@Component
export struct DiscoverPage {
  build() {
    Column() {
      Text('发现页').fontSize(30)
      Text('以图搜图和语音搜索入口将放在这里')
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
  }
}
import router from '@ohos.router';

interface ArtifactItem {
  id: number;
  name: string;
  era: string;
  image: string;
  similarity: number;
}

@Entry
@Component
export struct ImageSearchResultPage {
  private image: string = '';
  @State results: ArtifactItem[] = [];

  aboutToAppear() {
    let params = router.getParams() as Record<string, string>;

    this.image = params.image;

    if (params.results) {
      this.results = JSON.parse(params.results);
    }
  }

  build() {
    Column() {
      Text('以图搜图结果')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')               // 主文字色
        .margin({ top: 40, bottom: 20 })

      List() {
        ForEach(this.results, (item: ArtifactItem) => {
          ListItem() {
            Row() {
              Image(item.image)
                .width(120)
                .height(120)
                .borderRadius(12)
                .objectFit(ImageFit.Cover)

              Column() {
                Text(item.name)
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#3A3A3A')
                  .margin({ bottom: 10 })

                Text('年代：' + item.era)
                  .fontSize(16)
                  .fontColor('#8B7355')      // 辅助文字色
                  .margin({ bottom: 10 })

                Text('相似度：' + item.similarity + '%')
                  .fontSize(18)
                  .fontColor('#C05040')      // 敦煌红强调色
                  .fontWeight(FontWeight.Bold)
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 16 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .shadow({ radius: 6, color: '#18000000', offsetY: 2 })  // 与主页卡片同款阴影
          }
          .margin({ bottom: 16 })
        })
      }
      .width('92%')

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F0E8')               // 页面背景米白
    .alignItems(HorizontalAlign.Center)
  }
}
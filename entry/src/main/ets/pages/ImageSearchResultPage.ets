import router from '@ohos.router';

/**
 * 搜索结果单条（与 DiscoverPage 传过来的结构一致）。
 * similarity 为 0~1 的余弦相似度；objectId 用于跳详情页。
 */
interface SearchResultDTO {
  objectId: string;
  title: string;
  period: string;
  type: string;
  material: string;
  imageUrl: string;
  similarity: number;
}

@Entry
@Component
export struct ImageSearchResultPage {
  private image: string = '';
  @State results: SearchResultDTO[] = [];

  aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    if (!params) {
      return;
    }
    this.image = params.image ?? '';

    if (params.results) {
      const parsed = JSON.parse(params.results) as SearchResultDTO[];
      // 防御性再排一次序：按相似度降序
      parsed.sort((a: SearchResultDTO, b: SearchResultDTO): number => b.similarity - a.similarity);
      this.results = parsed;
    }
  }

  /** rawfile:// 走 $rawfile，其余（http 网络图/本地 uri）直接用字符串 */
  private toImageSrc(imageUrl: string): string | Resource {
    if (imageUrl.startsWith('rawfile://')) {
      return $rawfile(imageUrl.substring('rawfile://'.length));
    }
    return imageUrl;
  }

  /** 把 0~1 的相似度显示成百分比整数 */
  private toPercent(similarity: number): string {
    return Math.round(similarity * 100) + '%';
  }

  /** 点击结果项 -> 跳详情页，传 objectId */
  private gotoDetail(objectId: string) {
    router.pushUrl({
      url: 'pages/ArtifactDetailPage',
      params: { objectId: objectId }
    });
  }

  build() {
    Column() {
      Text('以图搜图结果')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')               // 主文字色
        .margin({ top: 40, bottom: 20 })

      if (this.results.length === 0) {
        // 空态：完全不沾边 / 低于阈值 -> 搜不到
        this.emptyState()
      } else {
        List() {
          ForEach(this.results, (item: SearchResultDTO) => {
            ListItem() {
              Row() {
                Image(this.toImageSrc(item.imageUrl))
                  .width(120)
                  .height(120)
                  .borderRadius(12)
                  .objectFit(ImageFit.Cover)
                  .backgroundColor('#E0D5C6')
                  .alt($r('app.media.startIcon'))

                Column() {
                  Text(item.title)
                    .fontSize(22)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#3A3A3A')
                    .margin({ bottom: 8 })

                  Text('年代：' + item.period)
                    .fontSize(15)
                    .fontColor('#8B7355')      // 辅助文字色
                    .margin({ bottom: 4 })

                  Text('类型：' + item.type + '  ·  材质：' + item.material)
                    .fontSize(14)
                    .fontColor('#8B7355')
                    .margin({ bottom: 8 })

                  Text('相似度：' + this.toPercent(item.similarity))
                    .fontSize(18)
                    .fontColor('#C05040')      // 敦煌红强调色
                    .fontWeight(FontWeight.Bold)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 16 })
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .shadow({ radius: 6, color: '#18000000', offsetY: 2 })  // 与主页卡片同款阴影
            }
            .margin({ bottom: 16 })
            .onClick(() => {
              this.gotoDetail(item.objectId);
            })
          })
        }
        .width('92%')
        .layoutWeight(1)
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F0E8')               // 页面背景米白
    .alignItems(HorizontalAlign.Center)
  }

  /** 搜不到时的空态 */
  @Builder
  emptyState() {
    Column({ space: 16 }) {
      Text('🔍')
        .fontSize(56)
      Text('搜不到相似文物')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3A3A3A')
      Text('这张图和库里的文物都不够像，换一张更接近的图再试试。')
        .fontSize(14)
        .fontColor('#8B7355')
        .textAlign(TextAlign.Center)
        .width('80%')
      Button('返回重拍 / 重选')
        .height(46)
        .fontSize(15)
        .backgroundColor('#C76B5A')
        .fontColor(Color.White)
        .borderRadius(12)
        .margin({ top: 8 })
        .onClick(() => {
          router.back();
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

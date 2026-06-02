// entry/src/main/ets/pages/ImageSearchResultPage.ets
import router from '@ohos.router';
import { BASE_URL } from '../common/Constants';

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
  private queryImageUri: string = '';
  @State results: SearchResultDTO[] = [];
  @State isGridMode: boolean = false; // false: 单列列表模式, true: 双列网格模式

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (!params) return;
    this.queryImageUri = (params.image as string) ?? '';
    const resultsStr = params.results as string;
    if (resultsStr) {
      try {
        const parsed = JSON.parse(resultsStr) as SearchResultDTO[];
        if (Array.isArray(parsed)) {
          parsed.sort((a, b) => b.similarity - a.similarity);
          this.results = parsed;
        } else {
          this.results = [];
        }
      } catch (e) {
        console.error('解析搜索结果失败', e);
        this.results = [];
      }
    } else {
      this.results = [];
    }
  }

  private toImageSrc(imageUrl: string): string {
    if (!imageUrl) return '';
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    if (imageUrl.startsWith('rawfile://')) {
      return imageUrl;
    }
    if (imageUrl.startsWith('/')) {
      return `${BASE_URL}${imageUrl}`;
    }
    return `${BASE_URL}/${imageUrl}`;
  }

  private toPercent(similarity: number): string {
    return Math.round(similarity * 100) + '%';
  }

  private gotoDetail(objectId: string) {
    router.pushUrl({
      url: 'pages/ArtifactDetailPage',
      params: { objectId: objectId }
    });
  }

  // 单列卡片（水平布局）
  @Builder
  buildListItem(item: SearchResultDTO) {
    Row() {
      Image(this.toImageSrc(item.imageUrl))
        .width(130)
        .height(130)
        .borderRadius(16)
        .objectFit(ImageFit.Cover)
        .backgroundColor('#EAE2D8')
        .alt($r('app.media.startIcon'))

      Column({ space: 6 }) {
        Text(item.title)
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`年代：${item.period || '未知'}`)
          .fontSize(14)
          .fontColor('#705C48')

        Text(`品类：${item.type || '无'} ｜ 材质：${item.material || '无'}`)
          .fontSize(13)
          .fontColor('#705C48')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`匹配相似度：${this.toPercent(item.similarity)}`)
          .fontSize(16)
          .fontColor('#D15543')
          .fontWeight(FontWeight.Medium)
      }
      .layoutWeight(1)
      .margin({ left: 18 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .shadow({ radius: 9, color: '#18000000', offsetY: 3 })
  }

  // 双列卡片（垂直布局）
  @Builder
  buildGridItem(item: SearchResultDTO) {
    Column() {
      Image(this.toImageSrc(item.imageUrl))
        .width('100%')
        .height(150)
        .borderRadius(16)
        .objectFit(ImageFit.Cover)
        .backgroundColor('#EAE2D8')
        .alt($r('app.media.startIcon'))

      Column({ space: 6 }) {
        Text(item.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`年代：${item.period || '未知'}`)
          .fontSize(13)
          .fontColor('#705C48')

        Text(`品类：${item.type || '无'}`)
          .fontSize(12)
          .fontColor('#705C48')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`相似度：${this.toPercent(item.similarity)}`)
          .fontSize(15)
          .fontColor('#D15543')
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .padding({ left: 8, right: 8, bottom: 12, top: 8 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .shadow({ radius: 6, color: '#15000000', offsetY: 2 })
    .onClick(() => this.gotoDetail(item.objectId))
    .padding(0)
  }

  build() {
    Column() {
      // ========== 顶部区域：返回按钮 + 居中检索原图 + 右侧数量/切换 ==========
      Row() {
        // 左侧返回按钮
        Button(" ← ", { stateEffect: true })
          .fontSize(15)
          .backgroundColor('#C76B5A')
          .fontColor(Color.White)
          .borderRadius(22)
          .width(80)
          .height(38)
          .onClick(() => router.back())

        // 中间区域：检索原图（居中显示）
        if (this.queryImageUri) {
          Row() {
            Image(this.queryImageUri)
              .width(80)
              .height(80)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
              .margin({ right: 10 })
            Text("原图")
              .fontSize(14)
              .fontColor('#8B7355')
          }
          .padding({ left: 10, right: 10, top: 2, bottom: 6 })
          .backgroundColor('#FFFFFF')
          .borderRadius(30)
          .shadow({ radius: 4, color: '#15000000', offsetY: 1 })
        } else {
          // 若无原图，留空占位保持布局
          Row().width(80)
        }

        // 右侧区域：统计数量 + 视图切换按钮
        Row({ space: 12 }) {
          // 共找到多少件文物
          Text(`共 ${this.results.length} 件`)
            .fontSize(14)
            .fontColor('#705C48')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#F0E8E0')
            .borderRadius(20)

          // 切换按钮组
          Row({ space: 4 }) {
            // 单列模式按钮
            Button() {
              Column() {
                Text('▮')
                  .fontSize(14)
                  .rotate({ angle: 90 })
                  .margin({ bottom: -4 })
                Text('单列')
                  .fontSize(10)
              }
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            }
            .width(44)
            .height(44)
            .backgroundColor(this.isGridMode ? '#F0E8E0' : '#C76B5A')
            .fontColor(this.isGridMode ? '#8B7355' : Color.White)
            .borderRadius(22)
            .onClick(() => {
              this.isGridMode = false;
            })

            // 双列模式按钮
            Button() {
              Column() {
                Text('▮▮')
                  .fontSize(14)
                  .letterSpacing(4)
                  .margin({ bottom: -4 })
                Text('双列')
                  .fontSize(10)
              }
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            }
            .width(44)
            .height(44)
            .backgroundColor(this.isGridMode ? '#C76B5A' : '#F0E8E0')
            .fontColor(this.isGridMode ? Color.White : '#8B7355')
            .borderRadius(22)
            .onClick(() => {
              this.isGridMode = true;
            })
          }
          .backgroundColor('#FFFFFFE6')
          .borderRadius(28)
          .padding(4)
        }
      }
      .width('94%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .margin({ top: 40, bottom: 16 })

      // ========== 结果列表区域（支持单列/双列切换） ==========
      if (this.results.length === 0) {
        this.emptyState()
      } else {
        if (!this.isGridMode) {
          // 单列模式：上下竖排List
          List({ space: 18 }) {
            ForEach(this.results, (item: SearchResultDTO) => {
              ListItem() {
                this.buildListItem(item)
              }
              .onClick(() => this.gotoDetail(item.objectId))
            }, (item: SearchResultDTO) => item.objectId)
          }
          .width('94%')
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
        } else {
          // 双列模式：横向两列Grid
          Grid() {
            ForEach(this.results, (item: SearchResultDTO) => {
              GridItem() {
                this.buildGridItem(item)
              }
            }, (item: SearchResultDTO) => item.objectId)
          }
          .columnsTemplate('1fr 1fr')
          .rowsGap(18)
          .columnsGap(16)
          .width('94%')
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
        }
      }
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F2E9')
    .alignItems(HorizontalAlign.Center)
  }

  // 空白页面（未找到文物时显示）
  @Builder
  emptyState() {
    Column({ space: 22 }) {
      Text('🔎')
        .fontSize(72)
      Text('暂无匹配文物')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#444444')
      Text('图片特征匹配度过低，请更换文物实拍图片重新搜索')
        .fontSize(15)
        .fontColor('#8B7355')
        .textAlign(TextAlign.Center)
        .width('85%')
      Button('返回重新拍照/选图')
        .width(220)
        .height(48)
        .fontSize(16)
        .backgroundColor('#C76B5A')
        .fontColor(Color.White)
        .borderRadius(24)
        .margin({ top: 12 })
        .onClick(() => router.back())
    }
    .width('90%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
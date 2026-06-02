// entry/src/main/ets/pages/ImageSearchResultPage.ets

import router from '@ohos.router';
import { BASE_URL } from '../common/Constants';

/**
 * 搜索结果单条（与 DiscoverPage 传过来的结构一致）
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
  private queryImageUri: string = '';
  @State results: SearchResultDTO[] = [];

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (!params) return;

    // 获取查询图片 URI（用于预览）
    this.queryImageUri = (params.image as string) ?? '';

    // 解析搜索结果
    const resultsStr = params.results as string;
    if (resultsStr) {
      try {
        const parsed = JSON.parse(resultsStr) as SearchResultDTO[];
        if (Array.isArray(parsed)) {
          // 按相似度降序排序
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

  /**
   * 将后端返回的图片 URL 转换为可加载的字符串
   * - 如果是完整 http/https 链接，直接使用
   * - 如果是相对路径（如 /static/xxx），拼接 BASE_URL
   * - 其他情况（如 rawfile://）保留原逻辑（实际很少用到）
   */
  private toImageSrc(imageUrl: string): string {
    if (!imageUrl) return '';
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    if (imageUrl.startsWith('rawfile://')) {
      // 理论上后端不会返回此格式，保留兼容
      return imageUrl;
    }
    // 相对路径：拼接 BASE_URL
    if (imageUrl.startsWith('/')) {
      return `${BASE_URL}${imageUrl}`;
    }
    return `${BASE_URL}/${imageUrl}`;
  }

  /**
   * 相似度转百分比字符串
   */
  private toPercent(similarity: number): string {
    return Math.round(similarity * 100) + '%';
  }

  /**
   * 跳转详情页
   */
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
        .fontColor('#3A3A3A')
        .margin({ top: 40, bottom: 20 })

      // 查询图片预览（可选，提升用户体验）
      if (this.queryImageUri) {
        Row() {
          Text('查询图片：')
            .fontSize(14)
            .fontColor('#8B7355')
          Image(this.queryImageUri)
            .width(80)
            .height(80)
            .borderRadius(8)
            .objectFit(ImageFit.Cover)
            .margin({ left: 12 })
        }
        .width('92%')
        .padding({ left: 16, top: 8, bottom: 8 })
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .margin({ bottom: 16 })
      }

      if (this.results.length === 0) {
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
                    .fontColor('#8B7355')
                    .margin({ bottom: 4 })

                  Text('类型：' + item.type + ' · 材质：' + item.material)
                    .fontSize(14)
                    .fontColor('#8B7355')
                    .margin({ bottom: 8 })

                  Text('相似度：' + this.toPercent(item.similarity))
                    .fontSize(18)
                    .fontColor('#C05040')
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
              .shadow({ radius: 6, color: '#18000000', offsetY: 2 })
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
    .backgroundColor('#F5F0E8')
    .alignItems(HorizontalAlign.Center)
  }

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
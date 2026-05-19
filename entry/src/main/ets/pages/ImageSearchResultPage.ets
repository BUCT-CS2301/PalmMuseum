import router from '@ohos.router';
import image from '@ohos.multimedia.image';
import promptAction from '@ohos.promptAction';

interface ArtifactItem {
  id: number;
  name: string;
  era: string;
  image: string;
  similarity: number;
}

interface RouterParams {
  image: string;
  results: string;
}

@Entry
@Component
export struct ImageSearchResultPage {
  @State userImageUri: string = '';
  @State resultList: ArtifactItem[] = [];
  @State userImagePixelMap: image.PixelMap | undefined = undefined;

  async aboutToAppear() {
    const params = router.getParams() as RouterParams;
    if (params) {
      this.userImageUri = params.image;
      try {
        // 明确指定解析类型
        const parsed: ArtifactItem[] = JSON.parse(params.results);
        this.resultList = parsed.sort((a, b) => b.similarity - a.similarity);
      } catch (e) {
        console.error('解析搜索结果失败', e);
        this.resultList = [];
      }
    } else {
      promptAction.showToast({ message: '参数错误' });
    }

    if (this.userImageUri) {
      await this.loadUserImageThumbnail();
    }
  }

  async loadUserImageThumbnail() {
    try {
      const imageSource: image.ImageSource = image.createImageSource(this.userImageUri);
      const decodingOptions: image.DecodingOptions = {
        desiredSize: { width: 200, height: 200 },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      const pixelMap: image.PixelMap = await imageSource.createPixelMap(decodingOptions);
      this.userImagePixelMap = pixelMap;
      imageSource.release();
    } catch (err) {
      console.error('加载用户图片失败', err);
    }
  }

  goBack() {
    router.back();
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left')) // 'chevron_left' 是返回箭头图标的名称
          .fontSize(24)
          .fontColor(['#000000'])
          .onClick(() => this.goBack());
        Text('以图搜图结果')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center);
        Blank().width(24);
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .backgroundColor('#FFFFFF');

      // 用户图片区域
      if (this.userImagePixelMap) {
        Column() {
          Text('您搜索的图片')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ bottom: 8 });
          Image(this.userImagePixelMap)
            .width('100%')
            .height(200)
            .objectFit(ImageFit.Contain)
            .borderRadius(12)
            .backgroundColor('#F5F5F5');
        }
        .width('92%')
        .padding(12)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .margin({ top: 16, bottom: 8 })
        .shadow({ radius: 4, color: '#0000000A', offsetY: 2 });
      }

      Text(`匹配到 ${this.resultList.length} 件相似文物`)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('92%')
        .margin({ top: 16, bottom: 8 })
        .alignSelf(ItemAlign.Start);

      List() {
        ForEach(this.resultList, (item: ArtifactItem, index: number) => {
          ListItem() {
            this.ArtifactCard(item, index + 1);
          }
          .margin({ bottom: 12 });
        }, (item: ArtifactItem) => item.id.toString());
      }
      .width('92%')
      .layoutWeight(1)
      .alignListItem(ListItemAlign.Center)
      .margin({ top: 8 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  ArtifactCard(item: ArtifactItem, rank: number) {
    Row() {
      Column() {
        Text(`${rank}`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF');
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor('#007AFF')
      .justifyContent(FlexAlign.Center)
      .margin({ right: 12 });

      Image(item.image)
        .width(70)
        .height(70)
        .objectFit(ImageFit.Cover)
        .borderRadius(8)
        .margin({ right: 12 });

      Column({ space: 4 }) {
        Text(item.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(item.era)
          .fontSize(13)
          .fontColor('#666666');
        Row() {
          Text('相似度: ')
            .fontSize(12)
            .fontColor('#999999');
          Text(`${item.similarity}%`)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F97316');
        }
        .margin({ top: 4 });
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor(['#8A8A8A']); // 一个中灰色
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({ radius: 2, color: '#00000008', offsetY: 1 })
    .onClick(() => {
      promptAction.showToast({ message: `查看详情：${item.name}` });
      // router.pushUrl({ url: 'pages/ArtifactDetailPage', params: { id: item.id } });
    });
  }
}
// ShowPage.ets
// 首页展示页：使用独立 MuseumArtifactApi 获取真实文物数据，实现轮播与精选推荐。
// 美化版：只调整首页 UI 展示，不修改公共 HttpApi.ets，不影响其他成员接口。

import { Artifact } from '../common/models/Artifact';
import { MuseumArtifactApi, ArtifactSearchResult } from '../common/network/MuseumArtifactApi';
import router from '@ohos.router';

@Entry
@Component
export struct ShowPage {
  @State showcaseList: Artifact[] = [];
  @State featuredList: Artifact[] = [];
  @State currentImageIndex: number = 0;
  @State isLoadingShowData: boolean = false;
  @State loadErrorText: string = '';
  @StorageLink('token') token: string = '';

  private retryTimer: number = -1;

  aboutToAppear() {
    this.loadShowData(true);
  }

  onPageShow() {
    // 从登录页、其他页面返回首页时重新加载，避免 token 刚保存时首页还是空白。
    this.loadShowData(true);
  }

  aboutToDisappear() {
    if (this.retryTimer !== -1) {
      clearTimeout(this.retryTimer);
      this.retryTimer = -1;
    }
  }

  private sortByPopularity(list: Artifact[]): Artifact[] {
    const sortedList: Artifact[] = [...list];
    sortedList.sort((a: Artifact, b: Artifact): number => {
      const ap: number = a.popularity ? a.popularity : 0;
      const bp: number = b.popularity ? b.popularity : 0;
      return bp - ap;
    });
    return sortedList;
  }

  private filterDisplayableArtifacts(list: Artifact[]): Artifact[] {
    return list.filter((item: Artifact): boolean => {
      return !!item && !!item.id && !!item.imageUrl && item.imageUrl.length > 0;
    });
  }

  private async requestHomeArtifacts(): Promise<Artifact[]> {
    const firstResult: ArtifactSearchResult = await MuseumArtifactApi.searchArtifacts({
      page: 1,
      size: 20,
      sortBy: 'hot'
    });

    let list: Artifact[] = this.filterDisplayableArtifacts(firstResult.items);

    if (list.length < 6) {
      try {
        const secondResult: ArtifactSearchResult = await MuseumArtifactApi.searchArtifacts({
          page: 2,
          size: 20,
          sortBy: 'hot'
        });
        list = list.concat(this.filterDisplayableArtifacts(secondResult.items));
      } catch (e) {
        console.warn(`[ShowPage] 第二页兜底数据加载失败：${JSON.stringify(e)}`);
      }
    }

    return this.sortByPopularity(list);
  }

  private async loadShowData(force: boolean = false) {
    if (this.isLoadingShowData) {
      return;
    }

    if (!force && this.showcaseList.length > 0 && this.featuredList.length > 0) {
      return;
    }

    if (!this.token || this.token.length === 0) {
      console.warn('[ShowPage] token 暂未准备好，延迟加载首页数据');
      if (this.retryTimer !== -1) {
        clearTimeout(this.retryTimer);
      }
      this.retryTimer = setTimeout(() => {
        this.retryTimer = -1;
        this.loadShowData(true);
      }, 500);
      return;
    }

    this.isLoadingShowData = true;
    this.loadErrorText = '';

    try {
      const list: Artifact[] = await this.requestHomeArtifacts();
      console.info(`[ShowPage] 首页真实数据数量=${list.length}`);

      this.showcaseList = list.slice(0, 5);
      this.featuredList = list.slice(0, 6);

      if (this.currentImageIndex >= this.showcaseList.length) {
        this.currentImageIndex = 0;
      }

      if (this.showcaseList.length === 0) {
        this.loadErrorText = '暂无可展示馆藏';
      }
    } catch (e) {
      console.error(`[ShowPage] 加载首页展示数据失败：${JSON.stringify(e)}`);
      this.showcaseList = [];
      this.featuredList = [];
      this.loadErrorText = '首页数据加载失败';
    } finally {
      this.isLoadingShowData = false;
    }
  }

  private goDetail(item: Artifact) {
    router.pushUrl({
      url: 'pages/ArtifactDetailPage',
      params: { objectId: item.id }
    });
  }

  @Builder
  private SectionTitle(title: string, subTitle: string) {
    Column() {
      Row() {
        Text(title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3A2A1A')
        Blank()
        Text(subTitle)
          .fontSize(12)
          .fontColor('#A8794F')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Divider().strokeWidth(3).color('#B94735').width(34)
        Divider().strokeWidth(1).color('#E5D2BA').width('100%').margin({ left: 8 })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('90%')
    .margin({ top: 26, bottom: 14 })
  }

  @Builder
  private EmptyCard() {
    Column() {
      Text('🏛')
        .fontSize(42)
        .margin({ bottom: 12 })

      Text(this.isLoadingShowData ? '正在加载馆藏...' : (this.loadErrorText.length > 0 ? this.loadErrorText : '暂无首页数据'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#7B6245')

      if (!this.isLoadingShowData) {
        Button('重新加载')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#B94735')
          .borderRadius(20)
          .height(38)
          .padding({ left: 22, right: 22 })
          .margin({ top: 16 })
          .onClick(() => {
            this.loadShowData(true);
          })
      }
    }
    .width('100%')
    .height(330)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#FFFDF8')
    .borderRadius(22)
    .shadow({ radius: 18, color: '#22000000', offsetY: 8 })
  }

  @Builder
  private ShowcaseCard(item: Artifact) {
    Column() {
      Stack() {
        Image(item.imageUrl)
          .width('100%')
          .height(245)
          .objectFit(ImageFit.Contain)
          .backgroundColor('#F1E6D7')
          .borderRadius(18)
          .alt($r('app.media.startIcon'))

      }
      .width('100%')
      .height(245)

      Column() {
        Text(item.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2E241A')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(item.period && item.period.length > 0 ? item.period : '年代未知')
          .fontSize(13)
          .fontColor('#8B7355')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })

        Row() {
          Text(item.type && item.type.length > 0 ? item.type : '类型未知')
            .fontSize(12)
            .fontColor('#8B4A35')
            .backgroundColor('#F7E7DC')
            .borderRadius(12)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.material && item.material.length > 0 ? item.material : '材质未知')
            .fontSize(12)
            .fontColor('#80623F')
            .backgroundColor('#F3E9D7')
            .borderRadius(12)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: 8 })
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 18 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor('#FFFDF8')
    .borderRadius(24)
    .shadow({ radius: 18, color: '#24000000', offsetY: 8 })
    .onClick(() => {
      this.goDetail(item);
    })
  }

  @Builder
  private FeaturedCard(item: Artifact) {
    Row() {
      Image(item.imageUrl)
        .width(92)
        .height(92)
        .objectFit(ImageFit.Contain)
        .backgroundColor('#F1E6D7')
        .borderRadius(16)
        .alt($r('app.media.startIcon'))

      Column() {
        Text(item.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2E241A')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(item.period && item.period.length > 0 ? item.period : '年代未知')
          .fontSize(12)
          .fontColor('#8B7355')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })

        Row() {
          Text(item.museum && item.museum.length > 0 ? item.museum : '馆藏来源')
            .fontSize(11)
            .fontColor('#9A6D3A')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text('查看')
            .fontSize(12)
            .fontColor('#B94735')
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .margin({ top: 14 })
      }
      .layoutWeight(1)
      .margin({ left: 14 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFDF8')
    .borderRadius(20)
    .shadow({ radius: 10, color: '#18000000', offsetY: 5 })
    .margin({ bottom: 12 })
    .onClick(() => {
      this.goDetail(item);
    })
  }

  build() {
    Scroll() {
      Column() {
        // 顶部欢迎区：保留晕染背景色，形状改回铺满顶部
        Stack() {
          // 主视觉底色铺满顶部
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#84362E')

          // 边缘暖色晕染：让深红向边缘自然过渡
          Column()
            .width(280)
            .height(280)
            .backgroundColor('#32C99668')
            .borderRadius(140)
            .position({ x: -112, y: -112 })

          Column()
            .width(230)
            .height(230)
            .backgroundColor('#24F1D6A8')
            .borderRadius(115)
            .position({ x: 288, y: -88 })

          Column()
            .width(300)
            .height(190)
            .backgroundColor('#188E2D25')
            .borderRadius(95)
            .position({ x: 208, y: 68 })

          Column()
            .width(190)
            .height(190)
            .backgroundColor('#26F7E8CC')
            .borderRadius(95)
            .position({ x: -58, y: 82 })

          // 底部米色柔和过渡，避免红色和下方内容割裂
          Column()
            .width('100%')
            .height(54)
            .backgroundColor('#20F6EFE4')
            .position({ x: 0, y: 138 })

          // 顶部内容
          Text('✦')
            .fontSize(30)
            .fontColor('#45F8E8D0')
            .position({ x: 34, y: 26 })

          Text('✦')
            .fontSize(18)
            .fontColor('#40F8E8D0')
            .position({ x: 368, y: 38 })

          Text('掌上博物馆')
            .fontSize(42)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFF8EA')
            .fontFamily('myCustomFont')
            .textAlign(TextAlign.Center)
            .width('100%')
            .position({ x: 0, y: 34 })

          Column() {
            Row() {
              Divider().strokeWidth(1).color('#CFA889').width(50)
              Text('触摸历史 · 感受匠心')
                .fontSize(15)
                .fontColor('#F8E8D0')
                .textAlign(TextAlign.Center)
                .margin({ left: 12, right: 12 })
              Divider().strokeWidth(1).color('#CFA889').width(50)
            }
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .width('100%')

            Text('汇集千年瑰宝，开启掌上文化之旅')
              .fontSize(16)
              .fontColor('#FFF4DD')
              .fontFamily('myCustomFont')
              .textAlign(TextAlign.Center)
              .margin({ top: 13 })
          }
          .width('100%')
          .position({ x: 0, y: 93 })
        }
        .width('100%')
        .height(178)
        .borderRadius({ bottomLeft: 30, bottomRight: 30 })
        .clip(true)
        .shadow({ radius: 20, color: '#22000000', offsetY: 8 })

        this.SectionTitle('今日推荐', 'Popular Collections')

        Column() {
          if (this.showcaseList.length === 0) {
            this.EmptyCard()
          } else {
            Swiper() {
              ForEach(this.showcaseList, (item: Artifact) => {
                this.ShowcaseCard(item)
              }, (item: Artifact) => item.id)
            }
            .index(this.currentImageIndex)
            .autoPlay(true)
            .interval(3200)
            .indicator(true)
            .indicatorStyle({
              left: 0,
              bottom: 8,
              size: 7,
              mask: false,
              color: '#E4CDB3',
              selectedColor: '#B94735'
            })
            .onChange((index: number) => {
              this.currentImageIndex = index;
            })
            .width('100%')
            .height(390)
          }
        }
        .width('90%')

        this.SectionTitle('精选馆藏', 'Featured Artifacts')

        Column() {
          if (this.featuredList.length === 0) {
            Column() {
              Text(this.isLoadingShowData ? '正在加载精选馆藏...' : '暂无精选馆藏')
                .fontSize(14)
                .fontColor('#8B7355')
            }
            .width('100%')
            .height(120)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor('#FFFDF8')
            .borderRadius(18)
          } else {
            ForEach(this.featuredList.slice(0, 4), (item: Artifact) => {
              this.FeaturedCard(item)
            }, (item: Artifact) => item.id)
          }
        }
        .width('90%')

        Column().height(28)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#F6EFE4')
      .padding({ bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6EFE4')
    .scrollBar(BarState.Auto)
  }
}

// HomePage.ets（敦煌色系 + 优化）
import { Artifact } from '../common/models/Artifact';
import { MuseumArtifactApi, ArtifactFilterOptions, ArtifactSearchResult } from '../common/network/MuseumArtifactApi';
import router from '@ohos.router';

interface FilterConfig {
  label: string;
  options: string[];
  value: string;
  onChange: (val: string) => void;
}

@Entry
@Component
export struct HomePage {
  private allArtifacts: Artifact[] = [];
  @State totalCount: number = 0;

  @State displayList: Artifact[] = [];
  @State searchKeyword: string = '';
  @State sortBy: string = 'hot';
  @State filterPeriod: string = '全部';
  @State filterType: string = '全部';
  @State filterMaterial: string = '全部';
  @State filterMuseum: string = '全部';
  @State viewMode: number = 0;

  @State periods: string[] = [];
  @State types: string[] = [];
  @State materials: string[] = [];
  @State museums: string[] = [];
  private filterApiLoaded: boolean = false;

  @State currentPage: number = 1;
  private pageSize: number = 10;
  @State totalFilteredList: Artifact[] = [];
  @State hasMore: boolean = false;

  @State showMoreFilters: boolean = false;
  private searchTimer: number = -1;

  aboutToAppear() {
    this.searchKeyword = '';
    this.filterPeriod = '全部';
    this.filterType = '全部';
    this.filterMaterial = '全部';
    this.filterMuseum = '全部';
    this.sortBy = 'hot';
    this.currentPage = 1;
    this.initFilterOptions();
    this.refreshList();
  }

  aboutToDisappear() {
    if (this.searchTimer !== -1) {
      clearTimeout(this.searchTimer);
      this.searchTimer = -1;
    }
  }

  private async initFilterOptions() {
    try {
      const options: ArtifactFilterOptions = await MuseumArtifactApi.getFilterOptions();
      this.periods = this.ensureAllOption(options.periods);
      this.types = this.ensureAllOption(options.types);
      this.materials = this.ensureAllOption(options.materials);
      this.museums = this.ensureAllOption(options.museums || []);
      this.filterApiLoaded = true;
      console.info(`[HomePage] 筛选接口加载成功 periods=${this.periods.length}, types=${this.types.length}, materials=${this.materials.length}, museums=${this.museums.length}`);

      // 如果筛选接口实际没有返回完整数据，就从真实搜索接口把全部文物分页拉一遍，再提取完整分类。
      // 这不是 mock，也不是写死；数据仍然来自后端接口。
      if (this.periods.length <= 1 || this.types.length <= 3 || this.materials.length <= 3 || this.museums.length <= 1) {
        console.warn('[HomePage] 筛选接口数据过少，开始从真实搜索接口分页提取完整筛选项');
        await this.loadFilterOptionsFromAllArtifacts();
      }
    } catch (e) {
      console.error(`[HomePage] 筛选接口加载失败，开始从真实搜索接口分页提取完整筛选项：${JSON.stringify(e)}`);
      await this.loadFilterOptionsFromAllArtifacts();
    }
  }

  private async loadFilterOptionsFromAllArtifacts() {
    const periodSet = new Set<string>();
    const typeSet = new Set<string>();
    const materialSet = new Set<string>();
    const museumSet = new Set<string>();

    let page = 1;
    const size = 100;
    let total = 0;
    let loaded = 0;

    try {
      do {
        const result: ArtifactSearchResult = await MuseumArtifactApi.searchArtifacts({
          page: page,
          size: size
        });

        total = result.total;
        loaded += result.items.length;

        result.items.forEach((item: Artifact) => {
          if (item.period && item.period.length > 0 && item.period !== 'unknown') {
            periodSet.add(item.period);
          }
          if (item.type && item.type.length > 0 && item.type !== 'unknown') {
            typeSet.add(item.type);
          }
          if (item.material && item.material.length > 0 && item.material !== 'unknown') {
            materialSet.add(item.material);
          }
          if (item.museum && item.museum.length > 0 && item.museum !== 'unknown') {
            museumSet.add(item.museum);
          }
        });

        page++;
      } while (loaded < total && page <= 20);

      this.periods = this.ensureAllOption(Array.from(periodSet));
      this.types = this.ensureAllOption(Array.from(typeSet));
      this.materials = this.ensureAllOption(Array.from(materialSet));
      this.museums = this.ensureAllOption(Array.from(museumSet));
      this.filterApiLoaded = true;
      console.info(`[HomePage] 搜索接口提取筛选项完成 loaded=${loaded}, total=${total}, periods=${this.periods.length}, types=${this.types.length}, materials=${this.materials.length}, museums=${this.museums.length}`);
    } catch (e) {
      this.filterApiLoaded = false;
      console.error(`[HomePage] 从搜索接口提取筛选项失败：${JSON.stringify(e)}`);
      this.periods = ['全部'];
      this.types = ['全部'];
      this.materials = ['全部'];
      this.museums = ['全部'];
    }
  }

  private ensureAllOption(list: string[]): string[] {
    const result: string[] = [];
    const set = new Set<string>();
    if (list) {
      list.forEach((value: string) => {
        if (value && value.length > 0 && value !== '全部' && !set.has(value)) {
          set.add(value);
          result.push(value);
        }
      });
    }
    return ['全部', ...result];
  }

  private getUniqueValues(field: string): string[] {
    const set = new Set<string>();
    for (const item of this.allArtifacts) {
      let value = '';
      switch (field) {
        case 'period': value = item.period; break;
        case 'type': value = item.type; break;
        case 'material': value = item.material; break;
        case 'museum': value = item.museum; break;
      }
      if (value && value.length > 0) {
        set.add(value);
      }
    }
    return ['全部', ...Array.from(set)];
  }


  // 接口筛选项为空/失败时，用已经拿到的真实列表数据补齐筛选栏，避免只剩“全部”
  private fillFilterOptionsFromArtifacts(list: Artifact[]) {
    const periodSet = new Set<string>();
    const typeSet = new Set<string>();
    const materialSet = new Set<string>();
    const museumSet = new Set<string>();

    list.forEach((item: Artifact) => {
      if (item.period && item.period.length > 0 && item.period !== 'unknown') {
        periodSet.add(item.period);
      }
      if (item.type && item.type.length > 0 && item.type !== 'unknown') {
        typeSet.add(item.type);
      }
      if (item.material && item.material.length > 0 && item.material !== 'unknown') {
        materialSet.add(item.material);
      }
      if (item.museum && item.museum.length > 0 && item.museum !== 'unknown') {
        museumSet.add(item.museum);
      }
    });

    if (this.periods.length <= 1 && periodSet.size > 0) {
      this.periods = ['全部', ...Array.from(periodSet)];
    }
    if (this.types.length <= 1 && typeSet.size > 0) {
      this.types = ['全部', ...Array.from(typeSet)];
    }
    if (this.materials.length <= 1 && materialSet.size > 0) {
      this.materials = ['全部', ...Array.from(materialSet)];
    }
    if (museumSet.size > 0) {
      this.museums = ['全部', ...Array.from(museumSet)];
    }
  }

  private chunkArray(arr: Artifact[], size: number): Artifact[][] {
    const result: Artifact[][] = [];
    for (let i = 0; i < arr.length; i += size) {
      result.push(arr.slice(i, i + size));
    }
    return result;
  }

  private readonly periodOrderMap: Map<string, number> = new Map([
    ['良渚文化', 1], ['新石器时代', 1], ['仰韶文化', 1],
    ['夏', 2], ['商', 3], ['西周', 4], ['春秋', 5], ['战国', 6],
    ['秦', 7], ['西汉', 8], ['东汉', 9], ['三国', 10],
    ['西晋', 11], ['东晋', 12], ['南北朝', 13], ['隋', 14],
    ['唐', 15], ['五代十国', 16], ['北宋', 17], ['宋', 17], ['南宋', 18],
    ['辽', 19], ['金', 20], ['元', 21], ['明', 22], ['清', 23],
    ['民国', 24], ['现代', 25]
  ]);

  private periodOrder(period: string): number {
    return this.periodOrderMap.get(period) ?? 99;
  }

  private sortCurrentList(list: Artifact[]): Artifact[] {
    const sorted = [...list];
    if (this.sortBy === 'hot') {
      sorted.sort((a, b) => (b.popularity ?? 0) - (a.popularity ?? 0));
    } else if (this.sortBy === 'name') {
      sorted.sort((a, b) => {
        try {
          return a.title.localeCompare(b.title, 'zh-CN');
        } catch (e) {
          return a.title.localeCompare(b.title);
        }
      });
    } else if (this.sortBy === 'period') {
      sorted.sort((a, b) => this.periodOrder(a.period) - this.periodOrder(b.period));
    }
    return sorted;
  }

  private async refreshList() {
    this.currentPage = 1;
    this.totalFilteredList = [];
    this.displayList = [];
    await this.fetchArtifactPage(true);
  }

  private async fetchArtifactPage(reset: boolean) {
    try {
      const result: ArtifactSearchResult = await MuseumArtifactApi.searchArtifacts({
        keyword: this.searchKeyword.trim(),
        page: this.currentPage,
        size: this.pageSize,
        period: this.filterPeriod,
        type: this.filterType,
        material: this.filterMaterial,
        sortBy: this.sortBy
      });

      this.totalCount = result.total;
      const merged = reset ? result.items : [...this.totalFilteredList, ...result.items];
      if (!this.filterApiLoaded) {
        this.fillFilterOptionsFromArtifacts(merged);
      }
      this.totalFilteredList = this.sortCurrentList(merged);
      this.displayList = this.totalFilteredList;
      this.hasMore = this.totalFilteredList.length < this.totalCount;
    } catch (e) {
      console.error(`[HomePage] 加载文物列表失败：${JSON.stringify(e)}`);
      this.totalCount = 0;
      this.totalFilteredList = [];
      this.displayList = [];
      this.hasMore = false;
    }
  }

  private updateDisplayList() {
    this.displayList = this.totalFilteredList;
    this.hasMore = this.totalFilteredList.length < this.totalCount;
  }

  private async loadMore() {
    if (this.hasMore) {
      this.currentPage++;
      await this.fetchArtifactPage(false);
    }
  }

  build() {
    Column() {
      // ===== 顶部主题区：与 ShowPage 的红色晕染风格呼应 =====
      Stack() {
        Column() {
          // 装饰晕染层
          Row() {
            Blank()
          }
          .width(160)
          .height(160)
          .backgroundColor('#A94C3E')
          .opacity(0.32)
          .borderRadius(80)
          .position({ x: -46, y: -50 })

          Row() {
            Blank()
          }
          .width(190)
          .height(190)
          .backgroundColor('#E8B987')
          .opacity(0.18)
          .borderRadius(95)
          .position({ x: 290, y: -72 })

          Row() {
            Column() {
              Text('馆藏文物')
                .fontSize(30)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFF8E8')
                .fontFamily('myCustomFont')

              Text('检索千年瑰宝 · 探索东方匠心')
                .fontSize(14)
                .fontColor('#F7D9B4')
                .margin({ top: 8 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text(this.viewMode === 0 ? '卡片' : '列表')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#843327')
              .backgroundColor('#F6D8A8')
              .borderRadius(18)
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .onClick(() => { this.viewMode = (this.viewMode + 1) % 2; })
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 24 })
          .alignItems(VerticalAlign.Center)

        }
        .width('100%')
        .height(108)
        .backgroundColor('#862F26')
        .borderRadius({ bottomLeft: 28, bottomRight: 28 })
        .clip(true)
      }
      .width('100%')
      .height(108)

      // ===== 搜索卡片 =====
      Row() {
        Text('🔍')
          .fontSize(18)
          .fontColor('#9A6C4A')
          .margin({ left: 14, right: 4 })

        TextInput({ placeholder: '搜索文物名称、年代、类型、材质...', text: this.searchKeyword })
          .placeholderFont({ size: 14 })
          .placeholderColor('#B6A897')
          .onChange((value: string) => {
            this.searchKeyword = value;
            if (this.searchTimer !== -1) {
              clearTimeout(this.searchTimer);
            }
            this.searchTimer = setTimeout(() => {
              this.refreshList();
            }, 300);
          })
          .layoutWeight(1)
          .height(42)
          .fontSize(14)
          .backgroundColor(Color.Transparent)
          .borderRadius(0)
          .padding({ left: 0 })

        if (this.searchKeyword.trim()) {
          Text('✕')
            .fontSize(15)
            .fontColor('#9A6C4A')
            .margin({ left: 8, right: 14 })
            .onClick(() => {
              this.searchKeyword = '';
              if (this.searchTimer !== -1) {
                clearTimeout(this.searchTimer);
                this.searchTimer = -1;
              }
              this.refreshList();
            })
        }
      }
      .width('92%')
      .height(52)
      .backgroundColor('#FFFDF8')
      .borderRadius(26)
      .shadow({ radius: 14, color: '#22000000', offsetY: 6 })
      .margin({ top: -18, bottom: 12 })

      // ===== 筛选区域 =====
      Column() {
        Row() {
          Row() {
            Text('筛选')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#3A2A1A')
            Text('  Filter')
              .fontSize(11)
              .fontColor('#B4815D')
          }
          .layoutWeight(1)

          Text(this.showMoreFilters ? '收起 ▲' : '展开 ▼')
            .fontSize(11)
            .fontColor('#B94735')
            .backgroundColor('#F7E5DB')
            .borderRadius(12)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .onClick(() => { this.showMoreFilters = !this.showMoreFilters; })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 6 })

        if (this.showMoreFilters) {
          Divider().strokeWidth(0.6).color('#EFE1D1').margin({ top: 6, bottom: 6 })

          this.FilterBar({ label: '年代', options: this.periods, value: this.filterPeriod,
            onChange: (val: string) => { this.filterPeriod = val; this.refreshList(); } })

          Column() {
            this.FilterBar({ label: '类型', options: this.types, value: this.filterType,
              onChange: (val: string) => { this.filterType = val; this.refreshList(); } })
          }
          .width('100%')
          .margin({ top: 6, bottom: 6 })

          this.FilterBar({ label: '材质', options: this.materials, value: this.filterMaterial,
            onChange: (val: string) => { this.filterMaterial = val; this.refreshList(); } })
        }
      }
      .width('92%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor('#FFFDF8')
      .borderRadius(16)
      .shadow({ radius: 10, color: '#14000000', offsetY: 5 })
      .margin({ bottom: 8 })

      // ===== 排序栏 =====
      Row() {
        Text('排序')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#3A2A1A')
          .margin({ right: 12 })

        Text('热门')
          .fontSize(13)
          .fontColor(this.sortBy === 'hot' ? '#FFFFFF' : '#8B7355')
          .backgroundColor(this.sortBy === 'hot' ? '#B94735' : '#FFFDF8')
          .borderRadius(16)
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .margin({ right: 6 })
          .onClick(() => { this.sortBy = 'hot'; this.refreshList(); })
        Text('名称')
          .fontSize(13)
          .fontColor(this.sortBy === 'name' ? '#FFFFFF' : '#8B7355')
          .backgroundColor(this.sortBy === 'name' ? '#B94735' : '#FFFDF8')
          .borderRadius(16)
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .margin({ right: 8 })
          .onClick(() => { this.sortBy = 'name'; this.refreshList(); })
        Text('年代')
          .fontSize(13)
          .fontColor(this.sortBy === 'period' ? '#FFFFFF' : '#8B7355')
          .backgroundColor(this.sortBy === 'period' ? '#B94735' : '#FFFDF8')
          .borderRadius(16)
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .onClick(() => { this.sortBy = 'period'; this.refreshList(); })
      }
      .width('92%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 8 })

      // ===== 内容区域 =====
      if (this.displayList.length === 0) {
        Column() {
          Text('🏺')
            .fontSize(56)
            .margin({ bottom: 12 })
          Text('暂无匹配文物')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#7B6245')
          Text('试试调整筛选条件或搜索关键词')
            .fontSize(14)
            .fontColor('#A8794F')
            .margin({ top: 6 })
        }
        .width('92%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#FFFDF8')
        .borderRadius(22)
        .margin({ bottom: 12 })
      } else if (this.viewMode === 0) {
        List() {
          ForEach(this.chunkArray(this.displayList, 2), (row: Artifact[]) => {
            ListItem() {
              Row() {
                ForEach(row, (item: Artifact) => {
                  Column() {
                    this.CardView(item)
                  }
                  .layoutWeight(1)
                  .margin({ left: 5, right: 5, top: 5, bottom: 5 })
                }, (item: Artifact) => item.id)
                if (row.length < 2) {
                  Column().layoutWeight(1).margin({ left: 5, right: 5, top: 5, bottom: 5 })
                }
              }
              .width('100%')
              .padding({ left: 7, right: 7 })
            }
            .width('100%')
          }, (row: Artifact[]) => `${row[0].id}_${row.length}`)

          if (this.hasMore) {
            ListItem() {
              Row() {
                Button('加载更多')
                  .width('58%')
                  .height(42)
                  .fontSize(14)
                  .backgroundColor('#B94735')
                  .fontColor('#FFFFFF')
                  .borderRadius(21)
                  .onClick(() => this.loadMore())
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
            }
            .width('100%')
            .margin({ top: 10, bottom: 12 })
          } else if (this.displayList.length > 0) {
            ListItem() {
              Text('已经到底了')
                .fontSize(12)
                .fontColor('#A8794F')
                .width('100%')
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .margin({ top: 10, bottom: 12 })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#F5EFE6')
        .divider(null)
      } else {
        List() {
          ForEach(this.displayList, (item: Artifact) => {
            ListItem() {
              this.ListView(item)
            }
            .margin({ top: 5, bottom: 5, left: 14, right: 14 })
          }, (item: Artifact) => item.id)

          if (this.hasMore) {
            ListItem() {
              Row() {
                Button('加载更多')
                  .width('58%')
                  .height(42)
                  .fontSize(14)
                  .backgroundColor('#B94735')
                  .fontColor('#FFFFFF')
                  .borderRadius(21)
                  .onClick(() => this.loadMore())
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
            }
            .width('100%')
            .margin({ top: 10, bottom: 12 })
          } else if (this.displayList.length > 0) {
            ListItem() {
              Text('已经到底了')
                .fontSize(12)
                .fontColor('#A8794F')
                .width('100%')
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .margin({ top: 10, bottom: 12 })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#F5EFE6')
        .divider(null)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5EFE6')
  }

  @Builder CardView(item: Artifact) {
    Column() {
      Image(item.imageUrl)
        .width('100%')
        .height(138)
        .objectFit(ImageFit.Contain)
        .backgroundColor('#F1E6D7')
        .borderRadius(16)

      Text(item.title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2E241A')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 10, bottom: 4 })
        .width('100%')

      Row() {
        Text(item.period && item.period.length > 0 ? item.period : '年代未知')
          .fontSize(11)
          .fontColor('#8B7355')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')

      Row() {
        Text(item.type && item.type.length > 0 ? item.type : '未知')
          .fontSize(11)
          .fontColor('#9A6C4A')
          .backgroundColor('#F4E9DE')
          .borderRadius(12)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(item.material && item.material.length > 0 ? item.material : '未知')
          .fontSize(11)
          .fontColor('#9A6C4A')
          .backgroundColor('#F4E9DE')
          .borderRadius(12)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .margin({ left: 6 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .padding(10)
    .backgroundColor('#FFFDF8')
    .borderRadius(18)
    .shadow({ radius: 12, color: '#18000000', offsetY: 5 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/ArtifactDetailPage', params: { objectId: item.id } });
    })
  }

  @Builder ListView(item: Artifact) {
    Row() {
      Image(item.imageUrl)
        .width(88)
        .height(88)
        .objectFit(ImageFit.Contain)
        .backgroundColor('#F1E6D7')
        .borderRadius(14)

      Column() {
        Text(item.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2E241A')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`${item.period} · ${item.type}`)
          .fontSize(12)
          .fontColor('#8B7355')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 7 })

        Text(item.material)
          .fontSize(12)
          .fontColor('#9A6C4A')
          .backgroundColor('#F4E9DE')
          .borderRadius(12)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .margin({ top: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFDF8')
    .borderRadius(18)
    .shadow({ radius: 10, color: '#16000000', offsetY: 5 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/ArtifactDetailPage', params: { objectId: item.id } });
    })
  }

  @Builder FilterBar(config: FilterConfig) {
    Row() {
      Text(config.label)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#7B6245')
        .width(36)
        .textAlign(TextAlign.Start)
        .margin({ right: 8 })

      Scroll() {
        Row() {
          ForEach(config.options, (option: string) => {
            Text(option)
              .fontSize(11)
              .fontColor(config.value === option ? '#FFFFFF' : '#6F5740')
              .fontWeight(config.value === option ? FontWeight.Medium : FontWeight.Normal)
              .backgroundColor(config.value === option ? '#B94735' : '#F4E9DE')
              .borderRadius(12)
              .padding({ left: 9, right: 9, top: 4, bottom: 4 })
              .margin({ right: 5 })
              .onClick(() => { config.onChange(option); })
          }, (option: string) => option)
        }
        .padding({ left: 0, right: 4 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

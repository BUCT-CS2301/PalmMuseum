
import { Artifact, mockArtifacts } from '../common/models/Artifact';
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
  private allArtifacts: Artifact[] = mockArtifacts;

  @State displayList: Artifact[] = [];
  @State searchKeyword: string = '';
  @State sortBy: string = 'name';
  @State filterPeriod: string = '全部';
  @State filterType: string = '全部';
  @State filterMaterial: string = '全部';
  @State filterMuseum: string = '全部';
  @State viewMode: number = 0; // 0: 卡片, 1: 列表

  @State periods: string[] = [];
  @State types: string[] = [];
  @State materials: string[] = [];
  @State museums: string[] = [];

  aboutToAppear() {
    this.initFilterOptions();
    this.updateList();
  }

  private initFilterOptions() {
    this.periods = this.getUniqueValues('period');
    this.types = this.getUniqueValues('type');
    this.materials = this.getUniqueValues('material');
    this.museums = this.getUniqueValues('museum');
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
      set.add(value);
    }
    return ['全部', ...Array.from(set)];
  }

  private updateList() {
    let list = [...this.allArtifacts];
    const kw = this.searchKeyword.trim().toLowerCase();
    if (kw) {
      list = list.filter(item =>
      item.title.toLowerCase().includes(kw) ||
        item.museum.toLowerCase().includes(kw)
      );
    }
    if (this.filterPeriod !== '全部') list = list.filter(item => item.period === this.filterPeriod);
    if (this.filterType !== '全部') list = list.filter(item => item.type === this.filterType);
    if (this.filterMaterial !== '全部') list = list.filter(item => item.material === this.filterMaterial);
    if (this.filterMuseum !== '全部') list = list.filter(item => item.museum === this.filterMuseum);

    if (this.sortBy === 'name') {
      list.sort((a, b) => a.title.localeCompare(b.title));
    } else if (this.sortBy === 'period') {
      list.sort((a, b) => a.period.localeCompare(b.period));
    }

    this.displayList = list;
    console.info('displayList 长度：' + this.displayList.length);
  }

  build() {
    Column() {
      // 搜索框 + 视图切换
      Row() {
        TextInput({ placeholder: '搜索文物名称或博物馆' })
          .onChange((value: string) => { this.searchKeyword = value; this.updateList(); })
          .layoutWeight(1).height(36).fontSize(14)

        Text(this.viewMode === 0 ? '📱' : '📋')
          .fontSize(20)
          .margin({ left: 10 })
          .onClick(() => { this.viewMode = (this.viewMode + 1) % 2; })
      }
      .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 4 }).backgroundColor('#F5F5F5')

      // 筛选行
      Scroll() {
        Row() {
          this.FilterBar({ label: '年代', options: this.periods, value: this.filterPeriod,
            onChange: (val: string) => { this.filterPeriod = val; this.updateList(); } })
          this.FilterBar({ label: '类型', options: this.types, value: this.filterType,
            onChange: (val: string) => { this.filterType = val; this.updateList(); } })
          this.FilterBar({ label: '材质', options: this.materials, value: this.filterMaterial,
            onChange: (val: string) => { this.filterMaterial = val; this.updateList(); } })
          this.FilterBar({ label: '博物馆', options: this.museums, value: this.filterMuseum,
            onChange: (val: string) => { this.filterMuseum = val; this.updateList(); } })
        }.padding({ left: 8, right: 8 })
      }
      .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).height(40)
      .backgroundColor('#FFFFFF').borderRadius(4).margin({ top: 4 })

      // 排序行
      Row() {
        Text('排序：').fontSize(13).fontColor('#666').margin({ right: 6 })
        Text('名称').fontSize(13).fontColor(this.sortBy === 'name' ? '#1A73E8' : '#666')
          .fontWeight(this.sortBy === 'name' ? FontWeight.Bold : FontWeight.Normal).margin({ right: 8 })
          .onClick(() => { this.sortBy = 'name'; this.updateList(); })
        Text('年代').fontSize(13).fontColor(this.sortBy === 'period' ? '#1A73E8' : '#666')
          .fontWeight(this.sortBy === 'period' ? FontWeight.Bold : FontWeight.Normal).margin({ right: 8 })
          .onClick(() => { this.sortBy = 'period'; this.updateList(); })
        Text('默认').fontSize(13).fontColor(this.sortBy === 'default' ? '#1A73E8' : '#666')
          .fontWeight(this.sortBy === 'default' ? FontWeight.Bold : FontWeight.Normal)
          .onClick(() => { this.sortBy = 'default'; this.updateList(); })
      }
      .width('100%').padding({ left: 12, right: 12, top: 4, bottom: 4 })
      .backgroundColor('#FFFFFF').border({ width: { bottom: 0.5 }, color: '#E0E0E0' })

      // 内容区域
      if (this.viewMode === 0) {
        Grid() {
          ForEach(this.displayList, (item: Artifact) => {
            GridItem() {
              this.CardView(item)
            }
          }, (item: Artifact) => item.id)
        }
        .columnsTemplate('1fr 1fr').columnsGap(8).rowsGap(8).padding(8)
        .width('100%').layoutWeight(1).backgroundColor('#F0F0F0')
      } else {
        List() {
          ForEach(this.displayList, (item: Artifact) => {
            ListItem() {
              this.ListView(item)
            }
          }, (item: Artifact) => item.id)
        }
        .width('100%').layoutWeight(1).backgroundColor('#F0F0F0').padding(8)
      }
    }
    .width('100%').height('100%').backgroundColor(Color.White)
  }

  // 卡片视图（带图片）
  @Builder CardView(item: Artifact) {
    Column() {
      // 图片（如果imageUrl无效可先使用占位图标测试）
      Image(item.imageUrl)
        .width('100%').aspectRatio(1).objectFit(ImageFit.Cover).borderRadius(8)

      Text(item.title)
        .fontSize(14).fontWeight(FontWeight.Medium).maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 6, bottom: 2 }).width('100%')

      Text(`${item.period} · ${item.museum}`)
        .fontSize(11).fontColor('#888').maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
    }
    .padding(8).backgroundColor(Color.White).borderRadius(8)
    .onClick(() => {
      router.pushUrl({ url: 'pages/ArtifactDetailPage', params: { objectId: item.id } });
    })
  }

  // 列表视图（带图片）
  @Builder ListView(item: Artifact) {
    Row() {
      Image(item.imageUrl)
        .width(80).height(80).objectFit(ImageFit.Cover).borderRadius(6)

      Column() {
        Text(item.title)
          .fontSize(16).fontWeight(FontWeight.Medium).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`${item.period} | ${item.type} | ${item.material}`)
          .fontSize(12).fontColor('#888').margin({ top: 4 })

        Text(item.museum)
          .fontSize(12).fontColor('#666').margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
    }
    .width('100%').padding(12).backgroundColor(Color.White).borderRadius(8).margin({ bottom: 4 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/ArtifactDetailPage', params: { objectId: item.id } });
    })
  }

  @Builder FilterBar(config: FilterConfig) {
    Row() {
      Text(config.label).fontSize(12).fontColor('#999').margin({ right: 4 })
      ForEach(config.options, (option: string) => {
        Text(option)
          .fontSize(12)
          .fontColor(config.value === option ? '#FFFFFF' : '#333')
          .backgroundColor(config.value === option ? '#1A73E8' : '#F0F0F0')
          .borderRadius(12)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .margin({ right: 4 })
          .onClick(() => { config.onChange(option); })
      }, (option: string) => option)
    }
  }
}
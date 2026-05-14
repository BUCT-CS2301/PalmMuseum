// common/models/Artifact.ets

// 定义一个文物类型（TypeScript 接口）
export interface Artifact {
  id: string;           // 文物唯一ID
  title: string;        // 名称
  imageUrl: string;     // 图片地址
  period: string;       // 年代
  type: string;         // 类型（瓷器、书画等）
  material: string;     // 材质
  description: string;  // 介绍
  museum: string;       // 收藏博物馆
}

// 模拟的文物数据（Mock Data），供开发时使用
export const mockArtifacts: Artifact[] = [
  {
    id: '1',
    title: '青花缠枝莲纹瓶',
    imageUrl: 'https://example.com/qinghua1.jpg',  // 暂时用假的，后面会替换
    period: '明·永乐',
    type: '瓷器',
    material: '瓷',
    description: '明代永乐年间青花瓷代表作，造型优美，纹饰流畅。',
    museum: '大英博物馆'
  },
  {
    id: '2',
    title: '唐三彩骆驼载乐俑',
    imageUrl: 'https://example.com/sancai.jpg',
    period: '唐',
    type: '陶器',
    material: '陶',
    description: '唐代三彩陶器，骆驼背上载有乐舞俑，反映丝绸之路文化。',
    museum: '大都会艺术博物馆'
  },
  {
    id: '3',
    title: '《富春山居图》局部',
    imageUrl: 'https://example.com/fuchun.jpg',
    period: '元',
    type: '书画',
    material: '纸本',
    description: '元代黄公望代表作，中国十大传世名画之一。',
    museum: '克利夫兰艺术博物馆'
  },
  {
    id: '4',
    title: '玉琮',
    imageUrl: 'https://example.com/yucong.jpg',
    period: '良渚文化',
    type: '玉器',
    material: '玉',
    description: '古代祭祀用玉器，内圆外方，象征天圆地方。',
    museum: '弗利尔美术馆'
  },
  {
    id: '5',
    title: '青铜爵',
    imageUrl: 'https://example.com/jue.jpg',
    period: '商',
    type: '青铜器',
    material: '青铜',
    description: '商代饮酒器，三足，流尾明显。',
    museum: '哈佛艺术博物馆'
  }
];
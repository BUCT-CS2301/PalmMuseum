// common/services/ImageSearchService.ets
//
// 以图搜图核心服务（纯逻辑，零 @ohos 依赖）。
//
// 设计要点：
// 1. 本文件不 import 任何 @ohos / @kit 设备 API，全部用「依赖注入」拿到解码器和数据源。
//    —— 这样它既能在 hypium 本地单测里被直接 import 测试，也能脱离真机用纯逻辑验证。
//    真实的图片解码（ImageKit）放在 ImageDecoder.ets，由上层 app 注入进来。
// 2. 特征提取是「确定性」的：同一份像素每次输出同一向量，方便写测试。
// 3. 比对用余弦相似度；向量经 L2 归一化后模长≈1，近重复图余弦≈1、不沾边的余弦低。

import type { Artifact } from '../models/Artifact';

// ---------------------------------------------------------------------------
// 特征向量维度常量
// ---------------------------------------------------------------------------

/** HSV 颜色直方图：色相 H 分 8 桶 */
const HSV_H_BINS = 8;
/** HSV 颜色直方图：饱和度 S 分 4 桶 */
const HSV_S_BINS = 4;
/** HSV 颜色直方图：明度 V 分 4 桶 */
const HSV_V_BINS = 4;
/** 颜色直方图总维度 = 8 * 4 * 4 = 128 */
const COLOR_DIM = HSV_H_BINS * HSV_S_BINS * HSV_V_BINS;

/** 灰度结构指纹：把图缩到 8x8 网格，取每格平均灰度（捕捉空间布局） */
const GRAY_GRID = 8;
/** 灰度结构总维度 = 8 * 8 = 64 */
const GRAY_DIM = GRAY_GRID * GRAY_GRID;

/** 拼接后的定长特征维度 = 128 + 64 = 192 */
export const FEATURE_DIM = COLOR_DIM + GRAY_DIM;

/** 近重复场景默认相似度阈值：低于它判为「搜不到」。轻量特征下近重复≈1，故取较高的 0.85 */
export const DEFAULT_THRESHOLD = 0.85;

/** 默认返回条数 */
export const DEFAULT_TOP_K = 5;

/**
 * rawfile uri 约定前缀。用它标记“图片在打包进 app 的 rawfile 里”。
 * 解码器(ImageDecoder) 见到该前缀就走 resourceManager 读取；数据源用 rawfileUri() 拼地址。
 * 放在纯逻辑层是为了让解码器和数据源共用同一套约定，避免前缀字符串写歪。
 */
export const RAWFILE_SCHEME = 'rawfile://';

/** 把 rawfile 文件名包成本服务识别的 uri，例如 rawfileUri('relics/1.png') */
export function rawfileUri(name: string): string {
  return RAWFILE_SCHEME + name;
}

// ---------------------------------------------------------------------------
// 类型定义
// ---------------------------------------------------------------------------

/** 解码后的原始像素：RGBA_8888，data 长度 = width * height * 4 */
export interface DecodedImage {
  data: Uint8Array;
  width: number;
  height: number;
}

/** 解码器：把一张图（uri / 网络地址 / rawfile 名）解码成像素。由上层注入。 */
export type ImageDecoder = (uri: string) => Promise<DecodedImage>;

/** 数据源：拉取文物列表。默认 mock，后端就绪后注入 HTTP 实现即可。 */
export type ArtifactSource = () => Promise<Artifact[]>;

/** 可选的持久化缓存（Preferences 实现由上层注入，纯逻辑层不依赖 @ohos） */
export interface VectorCache {
  load: () => Promise<VectorEntry[] | null>;
  save: (entries: VectorEntry[]) => Promise<void>;
}

/** 向量库的一条：文物 + 它的特征向量 */
export interface VectorEntry {
  artifact: Artifact;
  vector: number[];
}

/** 搜索结果：文物 + 相似度（0~1 的余弦值） */
export interface SearchResult {
  artifact: Artifact;
  similarity: number;
}

/** 服务构造参数（全部可选，便于测试只注入需要的部分） */
export interface ImageSearchConfig {
  decode?: ImageDecoder;
  source?: ArtifactSource;
  cache?: VectorCache;
  topK?: number;
  threshold?: number;
}

// ---------------------------------------------------------------------------
// 纯函数：RGB -> HSV
// ---------------------------------------------------------------------------

/**
 * 把单个像素的 RGB（0~255）转成 HSV。
 * h: 0~360，s: 0~1，v: 0~1。确定性纯计算。
 */
function rgbToHsv(r: number, g: number, b: number): number[] {
  const rf = r / 255;
  const gf = g / 255;
  const bf = b / 255;
  const max = Math.max(rf, gf, bf);
  const min = Math.min(rf, gf, bf);
  const delta = max - min;

  let h = 0;
  if (delta !== 0) {
    if (max === rf) {
      h = 60 * (((gf - bf) / delta) % 6);
    } else if (max === gf) {
      h = 60 * ((bf - rf) / delta + 2);
    } else {
      h = 60 * ((rf - gf) / delta + 4);
    }
  }
  if (h < 0) {
    h += 360;
  }

  const s = max === 0 ? 0 : delta / max;
  const v = max;
  return [h, s, v];
}

/** 把值 v 夹到 [0, maxIndex]，用于桶下标防越界 */
function clampBin(value: number, maxIndex: number): number {
  if (value < 0) {
    return 0;
  }
  if (value > maxIndex) {
    return maxIndex;
  }
  return value;
}

// ---------------------------------------------------------------------------
// 服务
// ---------------------------------------------------------------------------

export class ImageSearchService {
  private decode: ImageDecoder | undefined;
  private source: ArtifactSource | undefined;
  private cache: VectorCache | undefined;
  private topK: number;
  private threshold: number;

  /** 内存向量库 */
  private library: VectorEntry[] = [];

  constructor(config?: ImageSearchConfig) {
    this.decode = config?.decode;
    this.source = config?.source;
    this.cache = config?.cache;
    this.topK = config?.topK ?? DEFAULT_TOP_K;
    this.threshold = config?.threshold ?? DEFAULT_THRESHOLD;
  }

  // -------------------------------------------------------------------------
  // 1. extractImageFeature —— 对一张图提取归一化特征向量
  // -------------------------------------------------------------------------

  /**
   * 解码一张图并提取特征向量（依赖注入的解码器，真机上是 ImageKit）。
   * @param uri 图片地址：相册/拍照的 uri、网络 URL 或 rawfile 名（取决于注入的解码器）
   * @returns L2 归一化后的定长特征向量（长度 = FEATURE_DIM）
   */
  async extractImageFeature(uri: string): Promise<number[]> {
    if (!this.decode) {
      throw new Error('ImageSearchService: 未注入图片解码器 decode');
    }
    const img: DecodedImage = await this.decode(uri);
    return this.computeFeature(img.data, img.width, img.height);
  }

  /**
   * 纯函数：从 RGBA 像素直接算特征向量。确定性、可单测的核心。
   * 特征 = [HSV 颜色直方图 128 维] + [8x8 灰度结构 64 维]，整体 L2 归一化。
   * @param rgba RGBA_8888 像素数组（长度应为 width*height*4）
   */
  computeFeature(rgba: Uint8Array, width: number, height: number): number[] {
    if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
      // 异常输入：返回全零向量（其模长为 0，余弦相似度会判为不匹配）
      return new Array<number>(FEATURE_DIM).fill(0);
    }

    // 两块独立累加：颜色直方图 + 灰度网格
    const colorBlock: number[] = new Array<number>(COLOR_DIM).fill(0);
    const grayCellSum: number[] = new Array<number>(GRAY_DIM).fill(0);
    const grayCellCount: number[] = new Array<number>(GRAY_DIM).fill(0);

    let pixelCount = 0;
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const idx = (y * width + x) * 4;
        const r = rgba[idx];
        const g = rgba[idx + 1];
        const b = rgba[idx + 2];

        // —— 颜色直方图（HSV 分桶）——
        const hsv = rgbToHsv(r, g, b);
        const hBin = clampBin(Math.floor((hsv[0] / 360) * HSV_H_BINS), HSV_H_BINS - 1);
        const sBin = clampBin(Math.floor(hsv[1] * HSV_S_BINS), HSV_S_BINS - 1);
        const vBin = clampBin(Math.floor(hsv[2] * HSV_V_BINS), HSV_V_BINS - 1);
        const colorIdx = hBin * (HSV_S_BINS * HSV_V_BINS) + sBin * HSV_V_BINS + vBin;
        colorBlock[colorIdx] += 1;

        // —— 灰度结构（落到 8x8 网格）——
        const gray = 0.299 * r + 0.587 * g + 0.114 * b;
        const gx = clampBin(Math.floor((x * GRAY_GRID) / width), GRAY_GRID - 1);
        const gy = clampBin(Math.floor((y * GRAY_GRID) / height), GRAY_GRID - 1);
        const cell = gy * GRAY_GRID + gx;
        grayCellSum[cell] += gray;
        grayCellCount[cell] += 1;

        pixelCount++;
      }
    }

    // —— 颜色块：归一化为占比后，对该块单独做 L2 归一化（当作颜色分布的方向向量）——
    for (let i = 0; i < COLOR_DIM; i++) {
      colorBlock[i] = colorBlock[i] / pixelCount;
    }
    ImageSearchService.normalizeBlock(colorBlock);

    // —— 灰度结构块：每格平均灰度 -> 去均值（只保留相对明暗布局，剔除“整体亮度”这个公共 DC
    //    分量，否则任意两张图都会因为“都差不多亮”而余弦虚高，甚至纯色图也能匹配上）——
    const grayBlock: number[] = new Array<number>(GRAY_DIM).fill(0);
    let graySum = 0;
    for (let c = 0; c < GRAY_DIM; c++) {
      grayBlock[c] = grayCellCount[c] > 0 ? grayCellSum[c] / grayCellCount[c] : 0;
      graySum += grayBlock[c];
    }
    const grayMean = graySum / GRAY_DIM;
    for (let c = 0; c < GRAY_DIM; c++) {
      grayBlock[c] -= grayMean;
    }
    ImageSearchService.normalizeBlock(grayBlock); // 纯色图去均值后≈全零，归一化后仍为零 -> 不贡献相似度

    // —— 等权拼接两块，再对整体做 L2 归一化（保证模长≈1，且颜色/结构各占一半权重）——
    const feature: number[] = new Array<number>(FEATURE_DIM).fill(0);
    for (let i = 0; i < COLOR_DIM; i++) {
      feature[i] = colorBlock[i];
    }
    for (let c = 0; c < GRAY_DIM; c++) {
      feature[COLOR_DIM + c] = grayBlock[c];
    }
    return ImageSearchService.l2Normalize(feature);
  }

  /** 对一个向量块就地做 L2 归一化（零向量保持为零） */
  private static normalizeBlock(block: number[]): void {
    let sumSq = 0;
    for (let i = 0; i < block.length; i++) {
      sumSq += block[i] * block[i];
    }
    const norm = Math.sqrt(sumSq);
    if (norm === 0) {
      return;
    }
    for (let i = 0; i < block.length; i++) {
      block[i] = block[i] / norm;
    }
  }

  // -------------------------------------------------------------------------
  // 2. initArtifactVectors —— 拉文物、建本地向量库（带可选缓存）
  // -------------------------------------------------------------------------

  /**
   * 拉取文物数据，对每件文物的图片提特征，建本地向量库。
   * 优先读缓存；缓存未命中则逐条解码建库并写回缓存。
   * @param forceRebuild 为 true 时跳过缓存强制重建
   * @returns 建好的向量库
   */
  async initArtifactVectors(forceRebuild: boolean = false): Promise<VectorEntry[]> {
    // 1) 尝试读缓存
    if (!forceRebuild && this.cache) {
      const cached = await this.cache.load();
      if (cached && cached.length > 0) {
        this.library = cached;
        return this.library;
      }
    }

    if (!this.source) {
      throw new Error('ImageSearchService: 未注入数据源 source');
    }

    // 2) 拉文物列表
    const artifacts: Artifact[] = await this.source();
    // [诊断] 打印拉到多少条、前几条的图片地址（看后端 imageUrl 是完整 http 链接还是相对路径/空）
    let head = '';
    for (let i = 0; i < artifacts.length && i < 3; i++) {
      head += `${artifacts[i].id}=[${artifacts[i].imageUrl}] | `;
    }
    console.info(`[搜图诊断] 拉到文物 ${artifacts.length} 条；前几条图片地址：${head}`);
    const entries: VectorEntry[] = [];

    // 3) 逐条提特征。单条失败（图挂了/解码失败）只跳过该条，不影响整体建库
    let failCount = 0;
    for (let i = 0; i < artifacts.length; i++) {
      const art = artifacts[i];
      try {
        const vector = await this.extractImageFeature(art.imageUrl);
        entries.push({ artifact: art, vector: vector });
      } catch (e) {
        failCount++;
        // [诊断] 把失败文物的图片地址一并打出来，定位是哪类地址下不下来
        console.error(`initArtifactVectors: 文物 ${art.id} 提特征失败（图：${art.imageUrl}），已跳过: ${JSON.stringify(e)}`);
      }
    }
    console.info(`[搜图诊断] 建库完成：成功 ${entries.length} 条，失败 ${failCount} 条`);
    // [诊断] 打印前几张"已成功入库"的图片地址；下载其中一张存相册，用它搜即可验证"搜中"
    let okHead = '';
    for (let i = 0; i < entries.length && i < 5; i++) {
      okHead += entries[i].artifact.imageUrl + '  ';
    }
    console.info(`[搜图诊断] 库里可测试的图: ${okHead}`);

    this.library = entries;

    // 4) 写回缓存
    if (this.cache) {
      try {
        await this.cache.save(entries);
      } catch (e) {
        console.error(`initArtifactVectors: 缓存写入失败: ${JSON.stringify(e)}`);
      }
    }

    return this.library;
  }

  // -------------------------------------------------------------------------
  // 3. searchSimilarArtifacts —— 余弦检索 + 阈值过滤 + 降序 topK
  // -------------------------------------------------------------------------

  /**
   * 在向量库里检索与 queryVector 最相似的文物。
   * @param queryVector 查询图的特征向量
   * @param topK 最多返回几条（默认 5）
   * @param threshold 相似度门槛，低于它的过滤掉（默认 0.85，可配置）
   * @returns 按相似度降序、已过滤、最多 topK 条的结果（带 similarity）
   */
  searchSimilarArtifacts(queryVector: number[], topK?: number, threshold?: number): SearchResult[] {
    const k = topK ?? this.topK;
    const th = threshold ?? this.threshold;

    const scored: SearchResult[] = [];
    let maxSim = -1; // [诊断] 记录全库最高相似度，哪怕没过阈值也能看到
    for (let i = 0; i < this.library.length; i++) {
      const entry = this.library[i];
      const sim = ImageSearchService.cosineSimilarity(queryVector, entry.vector);
      if (sim > maxSim) {
        maxSim = sim;
      }
      if (sim >= th) {
        scored.push({ artifact: entry.artifact, similarity: sim });
      }
    }
    // [诊断] 库大小=0 → 建库失败（后端图没下下来）；库>0 但最高相似度低 → 选的图不在库里/非近重复（属正常搜不到）
    console.info(`[搜图诊断] 库大小=${this.library.length}, 阈值=${th}, 全库最高相似度=${maxSim}, 命中数=${scored.length}`);

    // 按相似度降序
    scored.sort((a: SearchResult, b: SearchResult): number => b.similarity - a.similarity);

    // 截断 topK
    return scored.slice(0, k);
  }

  // -------------------------------------------------------------------------
  // 工具/访问器
  // -------------------------------------------------------------------------

  /** L2 归一化：返回单位向量；零向量原样返回（避免除零） */
  static l2Normalize(vec: number[]): number[] {
    let sumSq = 0;
    for (let i = 0; i < vec.length; i++) {
      sumSq += vec[i] * vec[i];
    }
    const norm = Math.sqrt(sumSq);
    if (norm === 0) {
      return vec;
    }
    const out: number[] = new Array<number>(vec.length).fill(0);
    for (let i = 0; i < vec.length; i++) {
      out[i] = vec[i] / norm;
    }
    return out;
  }

  /** 余弦相似度：dot(a,b) / (|a||b|)。任一为零向量则返回 0 */
  static cosineSimilarity(a: number[], b: number[]): number {
    if (a.length !== b.length) {
      return 0;
    }
    let dot = 0;
    let na = 0;
    let nb = 0;
    for (let i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na === 0 || nb === 0) {
      return 0;
    }
    return dot / (Math.sqrt(na) * Math.sqrt(nb));
  }

  /** 直接设置向量库（测试用：注入已知向量库） */
  setLibrary(entries: VectorEntry[]): void {
    this.library = entries;
  }

  /** 当前向量库（只读访问） */
  getLibrary(): VectorEntry[] {
    return this.library;
  }

  /** 向量库条数 */
  get librarySize(): number {
    return this.library.length;
  }
}

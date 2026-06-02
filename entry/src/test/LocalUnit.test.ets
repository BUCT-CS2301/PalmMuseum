import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import {
  ImageSearchService,
  FEATURE_DIM,
  DEFAULT_THRESHOLD
} from '../main/ets/common/services/BackendImageSearchService.ets';
import type { DecodedImage, VectorEntry, SearchResult } from '../main/ets/common/services/BackendImageSearchService.ets';
import { Artifact, mockArtifacts } from '../main/ets/common/models/Artifact';

// ---------------------------------------------------------------------------
// 测试用工具：构造确定性数据，不依赖真机 / 网络 / 图片解码
// ---------------------------------------------------------------------------

/** 根据 seed 造一份确定性的 RGBA 像素（size*size 像素，每像素 4 字节） */
function fakeRgba(seed: number, size: number): Uint8Array {
  const buf = new Uint8Array(size * size * 4);
  for (let i = 0; i < size * size; i++) {
    buf[i * 4] = (seed * 7 + i * 3) % 256;
    buf[i * 4 + 1] = (seed * 13 + i * 5) % 256;
    buf[i * 4 + 2] = (seed * 17 + i * 11) % 256;
    buf[i * 4 + 3] = 255;
  }
  return buf;
}

/** 把字符串 uri 哈希成一个数字 seed（确定性） */
function hashUri(uri: string): number {
  let h = 0;
  for (let i = 0; i < uri.length; i++) {
    h = (h * 31 + uri.charCodeAt(i)) % 100000;
  }
  return h;
}

/** 一个确定性的假解码器：同一 uri 永远解出同一份像素 */
async function fakeDecode(uri: string): Promise<DecodedImage> {
  const size = 8;
  return { data: fakeRgba(hashUri(uri), size), width: size, height: size };
}

/** 构造一个最小可用的 Artifact（仅测试用） */
function makeArtifact(id: string): Artifact {
  return {
    id: id,
    title: '文物' + id,
    imageUrl: 'rawfile://relics/' + id + '.png',
    period: '测试朝代',
    type: '测试类型',
    material: '测试材质',
    description: '用于单测的文物',
    museum: '测试博物馆'
  };
}

/** 向量的 L2 模长 */
function l2norm(v: number[]): number {
  let s = 0;
  for (let i = 0; i < v.length; i++) {
    s += v[i] * v[i];
  }
  return Math.sqrt(s);
}

export default function localUnitTest() {
  describe('ImageSearchServiceTest', () => {
    beforeAll(() => {});
    beforeEach(() => {});
    afterEach(() => {});
    afterAll(() => {});

    // -----------------------------------------------------------------------
    // 1. extractImageFeature / computeFeature
    // -----------------------------------------------------------------------

    it('computeFeature_维度正确', 0, () => {
      const svc = new ImageSearchService();
      const feature = svc.computeFeature(fakeRgba(1, 8), 8, 8);
      expect(feature.length).assertEqual(FEATURE_DIM);
    });

    it('computeFeature_同一输入输出一致', 0, () => {
      const svc = new ImageSearchService();
      const buf = fakeRgba(42, 8);
      const f1 = svc.computeFeature(buf, 8, 8);
      const f2 = svc.computeFeature(buf, 8, 8);
      let identical = f1.length === f2.length;
      for (let i = 0; i < f1.length; i++) {
        if (f1[i] !== f2[i]) {
          identical = false;
          break;
        }
      }
      expect(identical).assertTrue();
    });

    it('computeFeature_L2归一化后模长约为1', 0, () => {
      const svc = new ImageSearchService();
      const feature = svc.computeFeature(fakeRgba(7, 8), 8, 8);
      const norm = l2norm(feature);
      // 非零向量经 L2 归一化，模长应≈1
      expect(Math.abs(norm - 1) < 1e-6).assertTrue();
    });

    it('extractImageFeature_经解码器提特征且确定性', 0, async () => {
      const svc = new ImageSearchService({ decode: fakeDecode });
      const v1 = await svc.extractImageFeature('photo://a');
      const v2 = await svc.extractImageFeature('photo://a');
      expect(v1.length).assertEqual(FEATURE_DIM);
      let same = true;
      for (let i = 0; i < v1.length; i++) {
        if (v1[i] !== v2[i]) {
          same = false;
          break;
        }
      }
      expect(same).assertTrue();
      expect(Math.abs(l2norm(v1) - 1) < 1e-6).assertTrue();
    });

    // -----------------------------------------------------------------------
    // 2. searchSimilarArtifacts
    // -----------------------------------------------------------------------

    // 构造一个已知向量库：
    //   art1 = [1,0,0]      与查询 [1,0,0] 完全相同 -> 余弦 1
    //   art2 = [0,1,0]      与查询正交           -> 余弦 0
    //   art3 = [0.95,0.05,0] 与查询几乎相同        -> 余弦≈0.999
    //   art4 = [0,0,1]      与查询正交           -> 余弦 0
    function buildKnownLibrary(): VectorEntry[] {
      return [
        { artifact: makeArtifact('1'), vector: [1, 0, 0] },
        { artifact: makeArtifact('2'), vector: [0, 1, 0] },
        { artifact: makeArtifact('3'), vector: [0.95, 0.05, 0] },
        { artifact: makeArtifact('4'), vector: [0, 0, 1] }
      ];
    }

    it('search_相同向量相似度约为1_正交向量约为0', 0, () => {
      expect(Math.abs(ImageSearchService.cosineSimilarity([1, 0, 0], [1, 0, 0]) - 1) < 1e-9).assertTrue();
      expect(Math.abs(ImageSearchService.cosineSimilarity([1, 0, 0], [0, 1, 0]) - 0) < 1e-9).assertTrue();
    });

    it('search_按相似度降序_并被阈值过滤', 0, () => {
      const svc = new ImageSearchService();
      svc.setLibrary(buildKnownLibrary());
      // 阈值 0.85：正交的 art2/art4(余弦0) 应被过滤，只剩 art1 和 art3
      const results: SearchResult[] = svc.searchSimilarArtifacts([1, 0, 0], 5, 0.85);
      expect(results.length).assertEqual(2);
      // 降序：第一条必须是完全相同的 art1
      expect(results[0].artifact.id).assertEqual('1');
      expect(results[1].artifact.id).assertEqual('3');
      // 严格降序
      expect(results[0].similarity >= results[1].similarity).assertTrue();
      // 完全相同的余弦≈1
      expect(Math.abs(results[0].similarity - 1) < 1e-9).assertTrue();
    });

    it('search_topK截断', 0, () => {
      const svc = new ImageSearchService();
      svc.setLibrary(buildKnownLibrary());
      const results = svc.searchSimilarArtifacts([1, 0, 0], 1, 0.5);
      expect(results.length).assertEqual(1);
      expect(results[0].artifact.id).assertEqual('1');
    });

    it('search_近重复进结果_差很远被判搜不到', 0, () => {
      const svc = new ImageSearchService();
      svc.setLibrary(buildKnownLibrary());

      // 近重复：[0.96,0.04,0] 与 art1[1,0,0]、art3[0.95,0.05,0] 余弦都很高 -> 能进结果
      const near = svc.searchSimilarArtifacts([0.96, 0.04, 0], 5, 0.85);
      expect(near.length > 0).assertTrue();
      expect(near[0].similarity >= 0.85).assertTrue();

      // 不沾边：[0,1,1] 与库里任意向量余弦最高仅约 0.707，低于阈值 0.85 -> 搜不到（空数组）
      const none = svc.searchSimilarArtifacts([0, 1, 1], 5, 0.85);
      expect(none.length).assertEqual(0);
    });

    // -----------------------------------------------------------------------
    // 3. initArtifactVectors
    // -----------------------------------------------------------------------

    it('initArtifactVectors_建库后每条文物都有非空向量', 0, async () => {
      const svc = new ImageSearchService({
        decode: fakeDecode,
        source: async (): Promise<Artifact[]> => mockArtifacts
      });
      const library = await svc.initArtifactVectors();

      // 每条 mock 文物都建出一条
      expect(library.length).assertEqual(mockArtifacts.length);
      expect(svc.librarySize).assertEqual(mockArtifacts.length);

      // 每条向量都非空、维度正确、模长≈1（即真实有内容，不是空/零向量）
      let allValid = true;
      for (let i = 0; i < library.length; i++) {
        const vec = library[i].vector;
        if (vec.length !== FEATURE_DIM || Math.abs(l2norm(vec) - 1) > 1e-6) {
          allValid = false;
          break;
        }
      }
      expect(allValid).assertTrue();
    });

    it('initArtifactVectors_默认阈值常量合理', 0, () => {
      // 近重复场景阈值应偏高（说明确实在“严格匹配”），这里校验默认值就是约定的 0.85
      expect(DEFAULT_THRESHOLD).assertEqual(0.85);
    });
  });
}

// common/services/ArtifactRepository.ets
//
// 文物数据源：给 ImageSearchService 注入 source。两种实现，可切换：
//   - createMockArtifactSource：默认。基于项目已有的 mockArtifacts，把图片地址指向 rawfile，
//     用于离线建库、联通整条流程。后端地址没来时用它。
//   - createHttpArtifactSource：走后端 GET /api/v1/data/relics（分页），并把后端字段适配成
//     前端的 Artifact 模型。后端就绪后，页面改成注入这个即可切到真实数据。
//
// 本文件依赖 HttpApi（设备网络），仅被页面引用，单测不引用。

import { Artifact, mockArtifacts } from '../models/Artifact';
import { HttpApi } from '../network/HttpApi';
import { rawfileUri } from './ImageSearchService';
import type { ArtifactSource } from './ImageSearchService';

// ---------------------------------------------------------------------------
// 后端响应结构（对应 {code,message,data:{records,total,page,pageSize}}）
// ---------------------------------------------------------------------------

/** 后端文物记录（字段对齐后端文物列表接口） */
interface RelicRecord {
  objectId: string;
  title: string;
  period: string;
  type: string;
  material: string;
  description: string;
  museumId: string;
  detailUrl?: string;
  imageUrl?: string;
  imagePath?: string;
  createTime?: string;
}

interface RelicListData {
  records: RelicRecord[];
  total: number;
  page: number;
  pageSize: number;
}

interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

// ---------------------------------------------------------------------------
// mock 数据源（rawfile 建库）
// ---------------------------------------------------------------------------

/**
 * 把一条 mock 文物的图片地址改写为 rawfile 地址，其余字段照搬。
 * 约定 rawfile 路径为 relics/<id>.png（见 resources/rawfile/relics/）。
 */
function toRawfileArtifact(a: Artifact): Artifact {
  const copy: Artifact = {
    id: a.id,
    title: a.title,
    imageUrl: rawfileUri(`relics/${a.id}.png`),
    period: a.period,
    type: a.type,
    material: a.material,
    description: a.description,
    museum: a.museum
  };
  if (a.imageUrls) {
    copy.imageUrls = a.imageUrls;
  }
  if (a.popularity !== undefined) {
    copy.popularity = a.popularity;
  }
  return copy;
}

/** 默认数据源：mock 文物，图片走 rawfile（离线建库） */
export function createMockArtifactSource(): ArtifactSource {
  return async (): Promise<Artifact[]> => {
    return mockArtifacts.map((a: Artifact): Artifact => toRawfileArtifact(a));
  };
}

// ---------------------------------------------------------------------------
// HTTP 数据源（后端就绪后切换）
// ---------------------------------------------------------------------------

/** 把后端文物记录适配成前端 Artifact 模型（字段名不同，做一次映射） */
function adaptRelic(r: RelicRecord): Artifact {
  return {
    id: r.objectId,
    title: r.title,
    imageUrl: r.imageUrl ?? r.imagePath ?? '',
    period: r.period,
    type: r.type,
    material: r.material,
    description: r.description,
    museum: r.museumId
  };
}

/**
 * 后端数据源：拉文物列表并适配。
 * @param pageSize 一次拉多少条（建库用，默认 100）
 */
export function createHttpArtifactSource(pageSize: number = 100): ArtifactSource {
  return async (): Promise<Artifact[]> => {
    const resp = await HttpApi.get<ApiResponse<RelicListData>>('/data/relics', {
      "page": '1',
      "pageSize": `${pageSize}`
    });
    if (!resp || resp.code !== 200 || !resp.data) {
      throw new Error(`拉取文物列表失败: ${resp ? resp.message : '空响应'}`);
    }
    // [诊断] 打印后端第一条原始记录的全部字段，用来核对正确的图片名/线索藏在哪个字段
    if (resp.data.records.length > 0) {
      console.info(`[搜图诊断] 后端原始记录样例: ${JSON.stringify(resp.data.records[0])}`);
    }
    return resp.data.records.map((r: RelicRecord): Artifact => adaptRelic(r));
  };
}

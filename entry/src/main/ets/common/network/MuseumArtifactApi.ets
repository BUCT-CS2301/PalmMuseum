// common/network/MuseumArtifactApi.ets
// 文物模块专用 API。只给 HomePage / ShowPage / ArtifactDetailPage 使用，不影响公共 HttpApi.ets。
// 本版新增：搜索列表按“文物核心信息”合并同一文物的多张图片，避免后端不同 objectId 的多图被渲染成多个卡片。

import http from '@ohos.net.http';
import { Artifact } from '../models/Artifact';

const MUSEUM_BASE_URL: string = 'http://60.205.14.101:8080/api/v1';

interface JsonHeaders {
  'Content-Type': string;
  'Accept': string;
  'Authorization'?: string;
}

interface ErrorResponse {
  code?: number;
  message?: string;
  data?: Object | null;
}

export interface MuseumApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

export interface ArtifactSearchParams {
  keyword?: string;
  page?: number;
  size?: number;
  period?: string;
  type?: string;
  material?: string;
  museum?: string;
  sortBy?: string;
}

export interface ArtifactSearchItem {
  objectId: string;
  title: string;
  period: string;
  type: string;
  material: string;
  museum: string;
  imageUrl: string;
  imageUrls?: string[];
  popularity?: number;
}

export interface ArtifactDetailItem {
  objectId: string;
  title: string;
  period: string;
  type: string;
  material: string;
  description?: string;
  dimensions?: string;
  museum: string;
  location?: string;
  detailUrl?: string;
  imageUrl: string;
  imageUrls?: string[];
  creditLine?: string;
  accessionNumber?: string;
  popularity?: number;
}

export interface ArtifactSearchData {
  total: number;
  page: number;
  size: number;
  items: ArtifactSearchItem[];
}

export interface ArtifactSearchResult {
  total: number;
  page: number;
  size: number;
  items: Artifact[];
}

export interface PeriodOption {
  value?: string;
  label?: string;
  order?: number;
}

export interface MuseumOption {
  objectId?: string;
  name?: string;
  label?: string;
  value?: string;
}

export interface ArtifactFilterData {
  periods?: Array<PeriodOption | string>;
  types?: string[];
  materials?: string[];
  museums?: Array<MuseumOption | string>;
  sortOptions?: string[];
}

export interface ArtifactFilterOptions {
  periods: string[];
  types: string[];
  materials: string[];
  museums: string[];
}

export class MuseumArtifactApi {
  private static readonly SEARCH_URL: string = '/artifacts/search';
  private static readonly DETAIL_URL: string = '/artifacts';
  private static readonly FILTER_URL: string = '/artifacts/filters';

  private static getToken(): string {
    const token = AppStorage.Get('token') as string;
    return token || '';
  }

  private static buildJsonHeaders(): JsonHeaders {
    const headers: JsonHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };

    const token: string = MuseumArtifactApi.getToken();
    if (token) {
      headers.Authorization = `Bearer ${token}`;
    }
    return headers;
  }

  private static getErrorMessage(raw: string, statusCode: number): string {
    if (!raw || raw.length === 0) {
      return `请求失败: ${statusCode}`;
    }
    try {
      const errorResp = JSON.parse(raw) as ErrorResponse;
      return errorResp.message || `请求失败: ${statusCode}`;
    } catch (e) {
      return `请求失败: ${statusCode}`;
    }
  }

  private static handleUnauthorized(): void {
    AppStorage.SetOrCreate('isLogin', false);
    AppStorage.SetOrCreate('token', '');
    AppStorage.SetOrCreate('refreshToken', '');
  }

  private static async get<T>(url: string): Promise<T> {
    const httpRequest = http.createHttp();
    const fullUrl: string = `${MUSEUM_BASE_URL}${url}`;

    try {
      console.info(`[MuseumArtifactApi REQ] GET ${fullUrl}`);
      const response = await httpRequest.request(fullUrl, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 10000,
        header: MuseumArtifactApi.buildJsonHeaders()
      });

      const raw: string = response.result as string;
      console.info(`[MuseumArtifactApi RESP] GET ${fullUrl} http=${response.responseCode} body=${raw}`);

      if (response.responseCode >= 200 && response.responseCode < 300) {
        return JSON.parse(raw) as T;
      }

      if (response.responseCode === 401) {
        MuseumArtifactApi.handleUnauthorized();
        throw new Error('登录已过期，请重新登录');
      }

      throw new Error(MuseumArtifactApi.getErrorMessage(raw, response.responseCode));
    } catch (e) {
      const error = e as Error;
      throw new Error(error.message || '网络请求异常');
    } finally {
      httpRequest.destroy();
    }
  }

  private static appendQuery(parts: string[], key: string, value?: string | number): void {
    if (value === undefined || value === null) {
      return;
    }
    const text: string = `${value}`.trim();
    if (text.length === 0 || text === '全部') {
      return;
    }
    parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(text)}`);
  }

  private static buildSearchUrl(params: ArtifactSearchParams): string {
    const parts: string[] = [];
    MuseumArtifactApi.appendQuery(parts, 'keyword', params.keyword);
    MuseumArtifactApi.appendQuery(parts, 'page', params.page || 1);
    MuseumArtifactApi.appendQuery(parts, 'size', params.size || 10);
    MuseumArtifactApi.appendQuery(parts, 'period', params.period);
    MuseumArtifactApi.appendQuery(parts, 'type', params.type);
    MuseumArtifactApi.appendQuery(parts, 'material', params.material);
    MuseumArtifactApi.appendQuery(parts, 'museum', params.museum);

    // sortBy 是页面前端排序字段，不传给后端，避免后端不支持参数导致空数据。
    if (parts.length === 0) {
      return MuseumArtifactApi.SEARCH_URL;
    }
    return `${MuseumArtifactApi.SEARCH_URL}?${parts.join('&')}`;
  }

  private static normalizeImageUrls(imageUrl?: string, imageUrls?: string[]): string[] {
    const urls: string[] = [];

    if (imageUrls && imageUrls.length > 0) {
      imageUrls.forEach((url: string) => {
        if (url && url.length > 0 && urls.indexOf(url) === -1) {
          urls.push(url);
        }
      });
    }

    if (imageUrl && imageUrl.length > 0 && urls.indexOf(imageUrl) === -1) {
      urls.push(imageUrl);
    }

    return urls;
  }

  private static toArtifact(item: ArtifactSearchItem | ArtifactDetailItem): Artifact {
    const detailItem = item as ArtifactDetailItem;
    const searchItem = item as ArtifactSearchItem;
    const urls: string[] = MuseumArtifactApi.normalizeImageUrls(item.imageUrl, searchItem.imageUrls || detailItem.imageUrls);

    return {
      id: item.objectId,
      title: item.title || '未命名文物',
      period: item.period || 'unknown',
      type: item.type || 'unknown',
      material: item.material || 'unknown',
      museum: item.museum || 'unknown',
      imageUrl: urls.length > 0 ? urls[0] : '',
      imageUrls: urls,
      description: detailItem.description || '暂无介绍',
      popularity: item.popularity || 0
    } as Artifact;
  }

  private static addImageUrls(target: string[], urls?: string[]): void {
    if (!urls || urls.length === 0) {
      return;
    }
    urls.forEach((url: string) => {
      if (url && url.length > 0 && target.indexOf(url) === -1) {
        target.push(url);
      }
    });
  }

  private static normalizeText(value?: string): string {
    if (!value) {
      return '';
    }
    return value.replace(/\s+/g, '').trim();
  }

  /**
   * 生成合并 key。
   *
   * 注意：你之前替换后“没有变化”，说明后端很可能把同一件文物的不同图片给了不同 objectId。
   * 所以这里不能只按 objectId 合并，而是按文物核心信息合并：
   * title + period + type + material + museum。
   *
   * 这样搜索列表中“同名、同年代、同类别、同材质、同博物馆”的记录会合成一件文物，
   * 多张图片进入 imageUrls，列表只显示一张卡片。
   */
  private static buildMergeKey(item: Artifact): string {
    const title: string = MuseumArtifactApi.normalizeText(item.title);
    const period: string = MuseumArtifactApi.normalizeText(item.period);
    const type: string = MuseumArtifactApi.normalizeText(item.type);
    const material: string = MuseumArtifactApi.normalizeText(item.material);
    const museum: string = MuseumArtifactApi.normalizeText(item.museum);

    const key: string = `${title}|${period}|${type}|${material}|${museum}`;
    if (key.replace(/\|/g, '').length > 0) {
      return key;
    }

    return item.id || '';
  }

  /**
   * 合并搜索结果里的同一文物多图。
   * 这里使用 buildMergeKey，而不是只用 objectId。
   */
  private static mergeSameArtifacts(list: Artifact[]): Artifact[] {
    const map: Map<string, Artifact> = new Map<string, Artifact>();

    list.forEach((item: Artifact) => {
      const key: string = MuseumArtifactApi.buildMergeKey(item);
      if (!key || key.length === 0) {
        return;
      }

      const oldItem: Artifact | undefined = map.get(key);
      if (!oldItem) {
        const urls: string[] = [];
        MuseumArtifactApi.addImageUrls(urls, item.imageUrls);
        MuseumArtifactApi.addImageUrls(urls, item.imageUrl ? [item.imageUrl] : []);
        item.imageUrls = urls;
        item.imageUrl = urls.length > 0 ? urls[0] : item.imageUrl;
        map.set(key, item);
        return;
      }

      const oldUrls: string[] = oldItem.imageUrls ? oldItem.imageUrls : [];
      MuseumArtifactApi.addImageUrls(oldUrls, item.imageUrls);
      MuseumArtifactApi.addImageUrls(oldUrls, item.imageUrl ? [item.imageUrl] : []);
      oldItem.imageUrls = oldUrls;
      oldItem.imageUrl = oldUrls.length > 0 ? oldUrls[0] : oldItem.imageUrl;

      // 保留较高热度。
      if ((item.popularity || 0) > (oldItem.popularity || 0)) {
        oldItem.popularity = item.popularity;
      }

      // 如果旧记录缺少介绍，而新记录有介绍，则补上。
      if ((!oldItem.description || oldItem.description === '暂无介绍') && item.description && item.description !== '暂无介绍') {
        oldItem.description = item.description;
      }

      map.set(key, oldItem);
    });

    const merged: Artifact[] = [];
    map.forEach((value: Artifact) => {
      merged.push(value);
    });
    return merged;
  }

  private static pushUnique(list: string[], value?: string): void {
    if (value && value.length > 0 && list.indexOf(value) < 0) {
      list.push(value);
    }
  }

  static async searchArtifacts(params: ArtifactSearchParams): Promise<ArtifactSearchResult> {
    const resp = await MuseumArtifactApi.get<MuseumApiResponse<ArtifactSearchData>>(
      MuseumArtifactApi.buildSearchUrl(params)
    );

    const data = resp.data;
    const rawItems: Artifact[] = data && data.items
      ? data.items.map((item: ArtifactSearchItem) => MuseumArtifactApi.toArtifact(item))
      : [];
    const mergedItems: Artifact[] = MuseumArtifactApi.mergeSameArtifacts(rawItems);

    console.info(`[MuseumArtifactApi] search raw=${rawItems.length}, merged=${mergedItems.length}`);

    return {
      // total 保留后端 total，避免分页“加载更多”被错误截断。
      total: data && data.total ? data.total : mergedItems.length,
      page: data && data.page ? data.page : (params.page || 1),
      size: data && data.size ? data.size : (params.size || 10),
      items: mergedItems
    };
  }

  static async getArtifactDetail(objectId: string): Promise<Artifact> {
    const resp = await MuseumArtifactApi.get<MuseumApiResponse<ArtifactDetailItem>>(
      `${MuseumArtifactApi.DETAIL_URL}/${encodeURIComponent(objectId)}`
    );
    return MuseumArtifactApi.toArtifact(resp.data);
  }

  static async getFilterOptions(): Promise<ArtifactFilterOptions> {
    const resp = await MuseumArtifactApi.get<MuseumApiResponse<ArtifactFilterData>>(
      MuseumArtifactApi.FILTER_URL
    );

    const periods: string[] = [];
    const types: string[] = [];
    const materials: string[] = [];
    const museums: string[] = [];
    const data = resp.data || {} as ArtifactFilterData;

    console.info(`[MuseumArtifactApi] raw filters data=${JSON.stringify(data)}`);

    if (data.periods) {
      const periodList = data.periods as Array<PeriodOption | string>;
      periodList
        .sort((a: PeriodOption | string, b: PeriodOption | string) => {
          const ao = typeof a === 'string' ? 999 : (a.order || 999);
          const bo = typeof b === 'string' ? 999 : (b.order || 999);
          return ao - bo;
        })
        .forEach((item: PeriodOption | string) => {
          if (typeof item === 'string') {
            MuseumArtifactApi.pushUnique(periods, item);
          } else {
            MuseumArtifactApi.pushUnique(periods, item.label || item.value || '');
          }
        });
    }

    if (data.types) {
      data.types.forEach((item: string) => MuseumArtifactApi.pushUnique(types, item));
    }

    if (data.materials) {
      data.materials.forEach((item: string) => MuseumArtifactApi.pushUnique(materials, item));
    }

    if (data.museums) {
      const museumList = data.museums as Array<MuseumOption | string>;
      museumList.forEach((item: MuseumOption | string) => {
        if (typeof item === 'string') {
          MuseumArtifactApi.pushUnique(museums, item);
        } else {
          MuseumArtifactApi.pushUnique(museums, item.name || item.label || item.value || '');
        }
      });
    }

    console.info(`[MuseumArtifactApi] filters periods=${periods.length}, types=${types.length}, materials=${materials.length}, museums=${museums.length}`);
    return { periods, types, materials, museums } as ArtifactFilterOptions;
  }
}

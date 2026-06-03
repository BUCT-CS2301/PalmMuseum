import { Artifact } from '../models/Artifact';
import { HttpApi } from '../network/HttpApi';

interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

interface ArtifactDetailData {
  objectId?: string;
  title?: string;
  period?: string;
  type?: string;
  material?: string;
  description?: string;
  museum?: string;
  museumName?: string;
  museumId?: string;
  imageUrl?: string;
  imagePath?: string;
  imageUrls?: string[];
  popularity?: number;
}

export class ArtifactApi {
  private static detailCache: Map<string, Artifact> = new Map();

  static async getArtifactDetail(objectId: string): Promise<Artifact> {
    const artifactId: string = objectId ? objectId.trim() : '';
    if (!artifactId) {
      throw new Error('文物编号不能为空');
    }

    const cached: Artifact | undefined = ArtifactApi.detailCache.get(artifactId);
    if (cached) {
      return cached;
    }

    const res = await HttpApi.get<ApiResponse<ArtifactDetailData>>(`/data/relics/${artifactId}`);
    if (res.code !== 200 || !res.data) {
      throw new Error(res.message || '获取文物详情失败');
    }

    const artifact: Artifact = ArtifactApi.toArtifact(res.data);
    ArtifactApi.detailCache.set(artifact.id, artifact);
    return artifact;
  }

  static async getArtifactMap(objectIds: string[]): Promise<Map<string, Artifact>> {
    const result = new Map<string, Artifact>();
    const uniqueIds: string[] = [];

    objectIds.forEach((item: string) => {
      const id = item ? item.trim() : '';
      if (!id || uniqueIds.indexOf(id) > -1) {
        return;
      }
      uniqueIds.push(id);
    });

    await Promise.all(uniqueIds.map(async (artifactId: string) => {
      try {
        const artifact = await ArtifactApi.getArtifactDetail(artifactId);
        result.set(artifactId, artifact);
      } catch (error) {
        console.error(`[ArtifactApi] 获取文物详情失败 artifactId=${artifactId} error=${JSON.stringify(error)}`);
      }
    }));

    return result;
  }

  private static toArtifact(data: ArtifactDetailData): Artifact {
    const imageUrl: string = HttpApi.toAbsoluteUrl(data.imageUrl || data.imagePath || '');
    const imageUrls: string[] = ArtifactApi.normalizeImageUrls(data, imageUrl);

    return {
      id: data.objectId || '',
      title: data.title || '',
      imageUrl: imageUrl,
      imageUrls: imageUrls.length > 0 ? imageUrls : (imageUrl ? [imageUrl] : []),
      period: data.period || '',
      type: data.type || '',
      material: data.material || '',
      description: data.description || '',
      museum: data.museumName || data.museum || data.museumId || '',
      popularity: data.popularity
    };
  }

  private static normalizeImageUrls(data: ArtifactDetailData, primaryImage: string): string[] {
    const urls: string[] = [];
    const pushUrl = (value: string): void => {
      const absoluteUrl = HttpApi.toAbsoluteUrl(value);
      if (!absoluteUrl || urls.indexOf(absoluteUrl) > -1) {
        return;
      }
      urls.push(absoluteUrl);
    };

    if (data.imageUrls && data.imageUrls.length > 0) {
      data.imageUrls.forEach((item: string): void => {
        pushUrl(item);
      });
    }

    pushUrl(data.imageUrl || '');
    pushUrl(data.imagePath || '');
    pushUrl(primaryImage);
    return urls;
  }
}

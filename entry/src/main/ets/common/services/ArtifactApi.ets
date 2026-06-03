import { Artifact } from '../models/Artifact';
import { HttpApi } from '../network/HttpApi';

interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

type RawValue = Object | Object[] | string | number | boolean | null | undefined;
type RawRecord = Record<string, RawValue>;

function readRecord(value: RawValue): RawRecord {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as RawRecord;
  }
  return {};
}

function readString(record: RawRecord, keys: string[], fallback: string = ''): string {
  for (let index = 0; index < keys.length; index += 1) {
    const value = record[keys[index]];
    if (typeof value === 'string' && value.trim().length > 0) {
      return value;
    }
    if (typeof value === 'number') {
      return String(value);
    }
  }
  return fallback;
}

function readNumber(record: RawRecord, keys: string[]): number | undefined {
  for (let index = 0; index < keys.length; index += 1) {
    const value = record[keys[index]];
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string' && value.trim().length > 0) {
      const parsed = Number(value);
      if (!Number.isNaN(parsed)) {
        return parsed;
      }
    }
  }
  return undefined;
}

function readImageUrls(record: RawRecord, primaryImageUrl: string): string[] {
  const rawList = record['imageUrls'];
  if (Array.isArray(rawList)) {
    const urls = rawList
      .map((item: Object | string | number | boolean | null | undefined): string => {
        if (typeof item === 'string') {
          return item;
        }
        return '';
      })
      .filter((item: string) => item.length > 0);
    if (urls.length > 0) {
      return urls;
    }
  }

  if (primaryImageUrl) {
    return [primaryImageUrl];
  }
  return [];
}

export class ArtifactApi {
  private static mapArtifact(data: Object): Artifact {
    const record = readRecord(data);
    const imageUrl = readString(record, ['imageUrl', 'imagePath'], '');
    return {
      id: readString(record, ['objectId', 'id']),
      title: readString(record, ['title', 'artifactTitle'], ''),
      imageUrl: imageUrl,
      imageUrls: readImageUrls(record, imageUrl),
      period: readString(record, ['period'], ''),
      type: readString(record, ['type'], ''),
      material: readString(record, ['material'], ''),
      description: readString(record, ['description'], ''),
      museum: readString(record, ['museum', 'museumName', 'museumId'], ''),
      popularity: readNumber(record, ['popularity'])
    };
  }

  static async getArtifactDetail(objectId: string): Promise<Artifact> {
    const response = await HttpApi.get<ApiResponse<Object>>(`/data/relics/${objectId}`);
    if (response.code !== 200 || !response.data) {
      throw new Error(response.message || '加载文物详情失败');
    }
    return ArtifactApi.mapArtifact(response.data);
  }
}

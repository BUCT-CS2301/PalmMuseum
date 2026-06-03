import common from '@ohos.app.ability.common';
import { Artifact } from '../models/Artifact';
import {
  CommentItem,
  CreatedAtItem,
  FAVORITE_GROUPS,
  FavoriteGroupSummary,
  FavoriteItem,
  HistoryItem,
  InteractionSummary,
  LikeItem,
  PrivacySettings,
  ReviewStatus,
  UploadedPhotoItem,
  UploadDraft,
  UserInteractionStats
} from '../models/InteractionModels';
import { HttpApi } from '../network/HttpApi';
import { ArtifactApi } from '../services/ArtifactApi';
import { PrivacyService } from '../services/PrivacyService';
import { preferencesUtil } from '../utils/PreferencesUtil';

interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

interface CommentResult {
  ok: boolean;
  message: string;
}

interface BackendListData<T> {
  items?: T[];
  records?: T[];
  list?: T[];
}

type BackendListPayload<T> = T[] | BackendListData<T> | null;

interface BackendLikeSummaryData {
  isLiked?: boolean;
  likeCount?: number;
  count?: number;
}

interface BackendFavoriteSummaryData {
  isFavorited?: boolean;
  favoriteCount?: number;
  count?: number;
  groupName?: string;
}

interface BackendFavoriteRecord {
  artifactId?: string;
  objectId?: string;
  artifactTitle?: string;
  title?: string;
  imageUrl?: string;
  period?: string;
  museum?: string;
  museumName?: string;
  groupName?: string;
  createTime?: string;
  createdAt?: string;
}

interface BackendHistoryRecord {
  artifactId?: string;
  objectId?: string;
  artifactTitle?: string;
  title?: string;
  imageUrl?: string;
  period?: string;
  museum?: string;
  museumName?: string;
  viewTime?: string;
  viewedAt?: string;
  createTime?: string;
}

interface BackendLikeRecord {
  artifactId?: string;
  objectId?: string;
  artifactTitle?: string;
  title?: string;
  imageUrl?: string;
  period?: string;
  museum?: string;
  museumName?: string;
  likeTime?: string;
  likedAt?: string;
  createTime?: string;
}

interface BackendCommentRecord {
  objectId?: string;
  commentId?: string;
  artifactId?: string;
  artifactTitle?: string;
  username?: string;
  content?: string;
  createTime?: string;
  createdAt?: string;
  status?: string;
  parentId?: string;
  replyTo?: string;
  likeCount?: number;
  isLiked?: boolean;
  likedByCurrentUser?: boolean;
}

interface BackendUploadRecord {
  uploadId?: string;
  objectId?: string;
  artifactId?: string;
  artifactTitle?: string;
  username?: string;
  imageUrl?: string;
  imagePath?: string;
  imageUri?: string;
  location?: string;
  description?: string;
  createTime?: string;
  createdAt?: string;
  status?: string;
}

interface BackendHistoryBody {
  artifactId: string;
}

interface BackendFavoriteBody {
  artifactId: string;
  groupName?: string;
}

interface BackendFavoriteMoveBody {
  groupName: string;
}

interface BackendCommentBody {
  content: string;
  parentId?: string;
  replyTo?: string;
}

interface EmptyRequestBody {
}

class InteractionStore {
  private readonly favoriteGroupKey = 'pm.favoriteGroups';

  private notifyInteractionChanged(): void {
    AppStorage.SetOrCreate('interactionVersion', Date.now());
  }

  private async syncProfileStats(username: string): Promise<void> {
    if (!username) {
      AppStorage.SetOrCreate('profileLikes', 0);
      AppStorage.SetOrCreate('profileFavorites', 0);
      AppStorage.SetOrCreate('profileComments', 0);
      AppStorage.SetOrCreate('profilePhotos', 0);
      this.notifyInteractionChanged();
      return;
    }

    const stats = await this.getStats(username);
    AppStorage.SetOrCreate('profileLikes', stats.likes);
    AppStorage.SetOrCreate('profileFavorites', stats.favorites);
    AppStorage.SetOrCreate('profileComments', stats.comments);
    AppStorage.SetOrCreate('profilePhotos', stats.photos);
    this.notifyInteractionChanged();
  }

  private async getJsonValue<T>(key: string, fallback: T): Promise<T> {
    try {
      const text = await preferencesUtil.getString(key, '');
      if (!text) {
        return fallback;
      }
      return JSON.parse(text) as T;
    } catch (error) {
      console.error(`[InteractionStore] 读取本地数据失败 key=${key} error=${JSON.stringify(error)}`);
      return fallback;
    }
  }

  private async setJsonValue<T>(key: string, value: T): Promise<void> {
    await preferencesUtil.putString(key, JSON.stringify(value));
  }

  private mapToObject<K, V>(map: Map<K, V>): Record<string, V> {
    const obj: Record<string, V> = {};
    map.forEach((value, key) => {
      obj[String(key)] = value;
    });
    return obj;
  }

  private objectToMap<V>(obj: Record<string, V>): Map<string, V> {
    const map = new Map<string, V>();
    Object.keys(obj).forEach((key: string) => {
      map.set(key, obj[key]);
    });
    return map;
  }

  private getDefaultFavoriteGroup(): string {
    return FAVORITE_GROUPS[0];
  }

  private uniqueStrings(items: string[]): string[] {
    const seen = new Set<string>();
    const result: string[] = [];

    items.forEach((item: string) => {
      const trimmed = item ? item.trim() : '';
      if (!trimmed || seen.has(trimmed)) {
        return;
      }
      seen.add(trimmed);
      result.push(trimmed);
    });

    return result;
  }

  private sortByDateDesc<T extends CreatedAtItem>(items: T[]): T[] {
    return [...items].sort((left: T, right: T) => {
      const leftTime = new Date(left.createdAt).getTime();
      const rightTime = new Date(right.createdAt).getTime();
      return rightTime - leftTime;
    });
  }

  private sortLikesByDateDesc(items: LikeItem[]): LikeItem[] {
    return [...items].sort((left: LikeItem, right: LikeItem) => {
      const leftTime = new Date(left.likedAt).getTime();
      const rightTime = new Date(right.likedAt).getTime();
      return rightTime - leftTime;
    });
  }

  private sortHistoryByDateDesc(items: HistoryItem[]): HistoryItem[] {
    return [...items].sort((left: HistoryItem, right: HistoryItem) => {
      const leftTime = new Date(left.viewedAt).getTime();
      const rightTime = new Date(right.viewedAt).getTime();
      return rightTime - leftTime;
    });
  }

  private extractList<T>(data: BackendListPayload<T>): T[] {
    if (!data) {
      return [];
    }
    if (Array.isArray(data)) {
      return data;
    }
    if (data.items && data.items.length > 0) {
      return data.items;
    }
    if (data.records && data.records.length > 0) {
      return data.records;
    }
    if (data.list && data.list.length > 0) {
      return data.list;
    }
    return [];
  }

  private toReviewStatus(status?: string): ReviewStatus {
    const normalized = status ? status.trim().toUpperCase() : '';
    return normalized === 'APPROVED' ? ReviewStatus.Approved : ReviewStatus.Pending;
  }

  private isApprovedStatus(status?: string): boolean {
    return this.toReviewStatus(status) === ReviewStatus.Approved;
  }

  private normalizeDateTime(value?: string): string {
    if (value && value.trim().length > 0) {
      return value;
    }
    return new Date().toISOString();
  }

  private toSummaryCount(data: BackendLikeSummaryData | BackendFavoriteSummaryData | null | undefined): number {
    if (!data) {
      return 0;
    }
    const likeCount = (data as BackendLikeSummaryData).likeCount;
    if (typeof likeCount === 'number') {
      return likeCount;
    }
    const favoriteCount = (data as BackendFavoriteSummaryData).favoriteCount;
    if (typeof favoriteCount === 'number') {
      return favoriteCount;
    }
    if (typeof data.count === 'number') {
      return data.count;
    }
    return 0;
  }

  private async loadLocalFavoriteGroups(username: string): Promise<string[]> {
    const groupObj = await this.getJsonValue<Record<string, string[]>>(this.favoriteGroupKey, {});
    const groupMap = this.objectToMap<string[]>(groupObj);
    const customGroups = username ? (groupMap.get(username) || []) : [];
    return this.uniqueStrings(customGroups);
  }

  private async saveLocalFavoriteGroups(username: string, groups: string[]): Promise<void> {
    const groupObj = await this.getJsonValue<Record<string, string[]>>(this.favoriteGroupKey, {});
    const groupMap = this.objectToMap<string[]>(groupObj);
    const customGroups = this.uniqueStrings(groups).filter((item: string) => FAVORITE_GROUPS.indexOf(item) === -1);
    groupMap.set(username, customGroups);
    await this.setJsonValue(this.favoriteGroupKey, this.mapToObject(groupMap));
  }

  private async buildFavoriteGroups(username: string, remoteGroups: string[] = []): Promise<string[]> {
    const localGroups = await this.loadLocalFavoriteGroups(username);
    return this.uniqueStrings([...FAVORITE_GROUPS, ...remoteGroups, ...localGroups]);
  }

  private async normalizeFavoriteGroupForUser(username: string, groupName: string): Promise<string> {
    const groups = await this.buildFavoriteGroups(username);
    return groups.indexOf(groupName) > -1 ? groupName : groups[0];
  }

  private async fetchFavoriteRecords(username: string): Promise<BackendFavoriteRecord[]> {
    const res = await HttpApi.get<ApiResponse<BackendListPayload<BackendFavoriteRecord>>>(`/users/${username}/favorites`);
    if (res.code !== 200) {
      throw new Error(res.message || '获取收藏列表失败');
    }
    return this.extractList(res.data);
  }

  private async fetchCommentRecordsForArtifact(artifactId: string): Promise<BackendCommentRecord[]> {
    const res = await HttpApi.get<ApiResponse<BackendListPayload<BackendCommentRecord>>>(`/artifacts/${artifactId}/comments`);
    if (res.code !== 200) {
      throw new Error(res.message || '获取评论列表失败');
    }
    return this.extractList(res.data);
  }

  private async fetchUserCommentRecords(username: string): Promise<BackendCommentRecord[]> {
    const res = await HttpApi.get<ApiResponse<BackendListPayload<BackendCommentRecord>>>(`/users/${username}/comments`);
    if (res.code !== 200) {
      throw new Error(res.message || '获取我的评论失败');
    }
    return this.extractList(res.data);
  }

  private async fetchUploadRecords(username: string): Promise<BackendUploadRecord[]> {
    const res = await HttpApi.get<ApiResponse<BackendListPayload<BackendUploadRecord>>>(`/users/${username}/uploads`);
    if (res.code !== 200) {
      throw new Error(res.message || '获取上传列表失败');
    }
    return this.extractList(res.data);
  }

  private async mapFavorites(records: BackendFavoriteRecord[], username: string): Promise<FavoriteItem[]> {
    const artifactIds: string[] = [];

    records.forEach((item: BackendFavoriteRecord) => {
      const artifactId = item.artifactId || item.objectId || '';
      const missingDetail = !item.imageUrl || !item.period || (!item.museum && !item.museumName);
      if (artifactId && missingDetail && artifactIds.indexOf(artifactId) === -1) {
        artifactIds.push(artifactId);
      }
    });

    const artifactMap = await ArtifactApi.getArtifactMap(artifactIds);
    const groupNames = records.map((item: BackendFavoriteRecord) => item.groupName || '').filter((item: string) => !!item);
    const groups = await this.buildFavoriteGroups(username, groupNames);
    const fallbackGroup = groups.length > 0 ? groups[0] : this.getDefaultFavoriteGroup();

    return records.map((item: BackendFavoriteRecord): FavoriteItem => {
      const artifactId = item.artifactId || item.objectId || '';
      const detail = artifactMap.get(artifactId);
      const favoriteGroup = item.groupName || fallbackGroup;

      return {
        artifactId: artifactId,
        title: item.artifactTitle || item.title || detail?.title || '',
        imageUrl: HttpApi.toAbsoluteUrl(item.imageUrl || detail?.imageUrl || ''),
        period: item.period || detail?.period || '',
        museum: item.museumName || item.museum || detail?.museum || '',
        groupName: groups.indexOf(favoriteGroup) > -1 ? favoriteGroup : fallbackGroup,
        createdAt: this.normalizeDateTime(item.createTime || item.createdAt)
      };
    });
  }

  private async mapLikes(records: BackendLikeRecord[]): Promise<LikeItem[]> {
    const artifactIds: string[] = [];

    records.forEach((item: BackendLikeRecord) => {
      const artifactId = item.artifactId || item.objectId || '';
      const missingDetail = !item.imageUrl || !item.period || (!item.museum && !item.museumName);
      if (artifactId && missingDetail && artifactIds.indexOf(artifactId) === -1) {
        artifactIds.push(artifactId);
      }
    });

    const artifactMap = await ArtifactApi.getArtifactMap(artifactIds);

    return records.map((item: BackendLikeRecord): LikeItem => {
      const artifactId = item.artifactId || item.objectId || '';
      const detail = artifactMap.get(artifactId);

      return {
        artifactId: artifactId,
        title: item.artifactTitle || item.title || detail?.title || '',
        imageUrl: HttpApi.toAbsoluteUrl(item.imageUrl || detail?.imageUrl || ''),
        period: item.period || detail?.period || '',
        museum: item.museumName || item.museum || detail?.museum || '',
        likedAt: this.normalizeDateTime(item.likeTime || item.likedAt || item.createTime)
      };
    });
  }

  private async mapHistory(records: BackendHistoryRecord[]): Promise<HistoryItem[]> {
    const artifactIds: string[] = [];

    records.forEach((item: BackendHistoryRecord) => {
      const artifactId = item.artifactId || item.objectId || '';
      const missingDetail = !item.imageUrl || !item.period || (!item.museum && !item.museumName);
      if (artifactId && missingDetail && artifactIds.indexOf(artifactId) === -1) {
        artifactIds.push(artifactId);
      }
    });

    const artifactMap = await ArtifactApi.getArtifactMap(artifactIds);

    return records.map((item: BackendHistoryRecord): HistoryItem => {
      const artifactId = item.artifactId || item.objectId || '';
      const detail = artifactMap.get(artifactId);

      return {
        artifactId: artifactId,
        title: item.artifactTitle || item.title || detail?.title || '',
        imageUrl: HttpApi.toAbsoluteUrl(item.imageUrl || detail?.imageUrl || ''),
        period: item.period || detail?.period || '',
        museum: item.museumName || item.museum || detail?.museum || '',
        viewedAt: this.normalizeDateTime(item.viewTime || item.viewedAt || item.createTime)
      };
    });
  }

  private mapComment(record: BackendCommentRecord, username: string = ''): CommentItem {
    const comment: CommentItem = {
      id: record.objectId || record.commentId || '',
      artifactId: record.artifactId || '',
      artifactTitle: record.artifactTitle || '',
      username: record.username || '',
      content: record.content || '',
      createdAt: this.normalizeDateTime(record.createTime || record.createdAt),
      status: this.toReviewStatus(record.status),
      likeCount: typeof record.likeCount === 'number' ? record.likeCount : 0,
      likedByCurrentUser: username ? !!(record.isLiked ?? record.likedByCurrentUser) : false
    };

    if (record.parentId) {
      comment.parentId = record.parentId;
    }
    if (record.replyTo) {
      comment.replyTo = record.replyTo;
    }
    return comment;
  }

  private async mapUploads(records: BackendUploadRecord[]): Promise<UploadedPhotoItem[]> {
    const artifactIds: string[] = [];

    records.forEach((item: BackendUploadRecord) => {
      const artifactId = item.artifactId || '';
      if (artifactId && !item.artifactTitle && artifactIds.indexOf(artifactId) === -1) {
        artifactIds.push(artifactId);
      }
    });

    const artifactMap = await ArtifactApi.getArtifactMap(artifactIds);

    return records.map((item: BackendUploadRecord): UploadedPhotoItem => {
      const artifactId = item.artifactId || '';
      const detail = artifactMap.get(artifactId);

      return {
        id: item.uploadId || item.objectId || '',
        artifactId: artifactId,
        artifactTitle: item.artifactTitle || detail?.title || '',
        username: item.username || '',
        imageUri: HttpApi.toAbsoluteUrl(item.imageUrl || item.imagePath || item.imageUri || ''),
        location: item.location || '',
        description: item.description || '',
        createdAt: this.normalizeDateTime(item.createTime || item.createdAt),
        status: this.toReviewStatus(item.status)
      };
    });
  }

  async getLikeSummary(artifactId: string, username: string = ''): Promise<InteractionSummary> {
    if (!artifactId) {
      return { active: false, count: 0 };
    }

    if (!username) {
      return { active: false, count: 0 };
    }

    try {
      const likes = await this.getLikes(username);
      const active = likes.some((item: LikeItem) => item.artifactId === artifactId);
      return {
        active: active,
        count: active ? 1 : 0
      };
    } catch (error) {
      console.warn(`[InteractionStore] 获取点赞摘要失败 artifactId=${artifactId} error=${JSON.stringify(error)}`);
      return { active: false, count: 0 };
    }
  }

  async toggleLike(artifactId: string, username: string, artifact?: Artifact): Promise<InteractionSummary> {
    const body: EmptyRequestBody = {};
    const res = await HttpApi.post<ApiResponse<BackendLikeSummaryData>>(`/artifacts/${artifactId}/likes`, body);
    if (res.code !== 200) {
      throw new Error(res.message || '点赞失败');
    }

    await this.syncProfileStats(username);
    return {
      active: !!res.data?.isLiked,
      count: this.toSummaryCount(res.data)
    };
  }

  async getLikes(username: string): Promise<LikeItem[]> {
    if (!username) {
      return [];
    }

    try {
      const res = await HttpApi.get<ApiResponse<BackendListPayload<BackendLikeRecord>>>(`/users/${username}/likes`);
      if (res.code !== 200) {
        throw new Error(res.message || '获取点赞列表失败');
      }
      return this.sortLikesByDateDesc(await this.mapLikes(this.extractList(res.data)));
    } catch (error) {
      console.error(`[InteractionStore] 点赞列表暂不可用 username=${username} error=${JSON.stringify(error)}`);
      throw new Error('当前服务暂不支持查看点赞列表');
    }
  }

  async removeLike(artifactId: string, username: string): Promise<void> {
    const summary = await this.toggleLike(artifactId, username);
    if (summary.active) {
      throw new Error('当前服务未返回取消点赞结果');
    }
  }

  async getFavoriteSummary(artifactId: string, username: string = ''): Promise<InteractionSummary> {
    if (!artifactId || !username) {
      return { active: false, count: 0 };
    }

    const favorites = await this.getFavorites(username);
    const active = favorites.some((item: FavoriteItem) => item.artifactId === artifactId);
    return {
      active: active,
      count: active ? 1 : 0
    };
  }

  async toggleFavorite(
    artifact: Artifact,
    username: string,
    groupName: string = FAVORITE_GROUPS[0]
  ): Promise<InteractionSummary> {
    const favorites = await this.getFavorites(username);
    const exists = favorites.some((item: FavoriteItem) => item.artifactId === artifact.id);
    const normalizedGroup = await this.normalizeFavoriteGroupForUser(username, groupName);

    if (exists) {
      const res = await HttpApi.delete<ApiResponse<BackendFavoriteSummaryData>>(`/users/${username}/favorites/${artifact.id}`);
      await this.syncProfileStats(username);
      return {
        active: !!(res.data && res.data.isFavorited),
        count: this.toSummaryCount(res.data)
      };
    }

    const body: BackendFavoriteBody = {
      artifactId: artifact.id,
      groupName: normalizedGroup
    };
    const res = await HttpApi.post<ApiResponse<BackendFavoriteSummaryData>>(`/users/${username}/favorites`, body);
    if (res.code !== 200) {
      throw new Error(res.message || '收藏失败');
    }

    await this.syncProfileStats(username);
    return {
      active: !!(res.data?.isFavorited ?? true),
      count: this.toSummaryCount(res.data)
    };
  }

  async getFavorites(username: string): Promise<FavoriteItem[]> {
    if (!username) {
      return [];
    }

    const records = await this.fetchFavoriteRecords(username);
    return this.sortByDateDesc<FavoriteItem>(await this.mapFavorites(records, username));
  }

  async getFavoriteGroups(username: string): Promise<string[]> {
    if (!username) {
      return [...FAVORITE_GROUPS];
    }

    const records = await this.fetchFavoriteRecords(username);
    const remoteGroups = records
      .map((item: BackendFavoriteRecord) => item.groupName || '')
      .filter((item: string) => !!item);
    return this.buildFavoriteGroups(username, remoteGroups);
  }

  async addFavoriteGroup(username: string, groupName: string): Promise<string[]> {
    const trimmed = groupName ? groupName.trim() : '';
    if (!username || !trimmed) {
      return this.getFavoriteGroups(username);
    }

    const currentGroups = await this.loadLocalFavoriteGroups(username);
    await this.saveLocalFavoriteGroups(username, [...currentGroups, trimmed]);
    return this.getFavoriteGroups(username);
  }

  async deleteFavoriteGroup(username: string, groupName: string): Promise<string[]> {
    if (!username || FAVORITE_GROUPS.indexOf(groupName) > -1) {
      return this.getFavoriteGroups(username);
    }

    const groups = await this.getFavoriteGroups(username);
    const nextGroups = groups.filter((item: string) => item !== groupName);
    const fallbackGroup = nextGroups.length > 0 ? nextGroups[0] : this.getDefaultFavoriteGroup();
    const favorites = await this.getFavorites(username);

    await Promise.all(
      favorites
        .filter((item: FavoriteItem) => item.groupName === groupName)
        .map((item: FavoriteItem) => this.moveFavoriteToGroup(item.artifactId, username, fallbackGroup))
    );

    await this.saveLocalFavoriteGroups(username, nextGroups);
    return this.getFavoriteGroups(username);
  }

  async getFavoriteGroupForArtifact(username: string, artifactId: string): Promise<string> {
    const favorites = await this.getFavorites(username);
    const target = favorites.find((item: FavoriteItem) => item.artifactId === artifactId);
    const groups = await this.getFavoriteGroups(username);
    return target ? target.groupName : (groups.length > 0 ? groups[0] : this.getDefaultFavoriteGroup());
  }

  async getFavoriteGroupSummaries(username: string): Promise<FavoriteGroupSummary[]> {
    const favorites = await this.getFavorites(username);
    const groups = await this.getFavoriteGroups(username);

    return groups.map((groupName: string): FavoriteGroupSummary => ({
      name: groupName,
      count: favorites.filter((item: FavoriteItem) => item.groupName === groupName).length,
      isDefault: FAVORITE_GROUPS.indexOf(groupName) > -1
    }));
  }

  async moveFavoriteToGroup(artifactId: string, username: string, groupName: string): Promise<string> {
    const normalizedGroup = await this.normalizeFavoriteGroupForUser(username, groupName);
    await this.addFavoriteGroup(username, normalizedGroup);

    const body: BackendFavoriteMoveBody = { groupName: normalizedGroup };

    try {
      const res = await HttpApi.put<ApiResponse<BackendFavoriteSummaryData>>(`/users/${username}/favorites/${artifactId}`, body);
      if (res.code !== 200) {
        throw new Error(res.message || '更新收藏分组失败');
      }
    } catch (error) {
      const fallbackBody: BackendFavoriteBody = {
        artifactId: artifactId,
        groupName: normalizedGroup
      };
      const res = await HttpApi.post<ApiResponse<BackendFavoriteSummaryData>>(`/users/${username}/favorites`, fallbackBody);
      if (res.code !== 200) {
        throw new Error(res.message || '更新收藏分组失败');
      }
    }

    return normalizedGroup;
  }

  async cycleFavoriteGroup(artifactId: string, username: string): Promise<string> {
    const groups = await this.getFavoriteGroups(username);
    const currentGroup = await this.getFavoriteGroupForArtifact(username, artifactId);
    const currentIndex = groups.indexOf(currentGroup);
    const nextIndex = currentIndex > -1 ? (currentIndex + 1) % groups.length : 0;
    return this.moveFavoriteToGroup(artifactId, username, groups[nextIndex]);
  }

  async removeFavorite(artifactId: string, username: string): Promise<void> {
    const res = await HttpApi.delete<ApiResponse<BackendFavoriteSummaryData>>(`/users/${username}/favorites/${artifactId}`);
    if (res.code !== undefined && res.code !== 200 && res.code !== 204) {
      throw new Error(res.message || '取消收藏失败');
    }
    await this.syncProfileStats(username);
  }

  async recordHistory(artifact: Artifact, username: string): Promise<void> {
    if (!artifact || !artifact.id || !username) {
      return;
    }

    const body: BackendHistoryBody = { artifactId: artifact.id };
    try {
      await HttpApi.post<ApiResponse<object>>(`/users/${username}/history`, body);
      this.notifyInteractionChanged();
    } catch (error) {
      console.warn(`[InteractionStore] 浏览记录接口暂不可用 artifactId=${artifact.id} error=${JSON.stringify(error)}`);
    }
  }

  async getHistory(username: string): Promise<HistoryItem[]> {
    if (!username) {
      return [];
    }

    try {
      const res = await HttpApi.get<ApiResponse<BackendListPayload<BackendHistoryRecord>>>(`/users/${username}/history`);
      if (res.code !== 200) {
        throw new Error(res.message || '获取浏览记录失败');
      }
      return this.sortHistoryByDateDesc(await this.mapHistory(this.extractList(res.data)));
    } catch (error) {
      console.error(`[InteractionStore] 浏览记录暂不可用 username=${username} error=${JSON.stringify(error)}`);
      throw new Error('当前服务暂不支持查看浏览记录');
    }
  }

  async getCommentsForArtifact(artifactId: string, username: string = ''): Promise<CommentItem[]> {
    const publicComments = (await this.fetchCommentRecordsForArtifact(artifactId))
      .map((item: BackendCommentRecord) => this.mapComment(item, username));

    if (!username) {
      return this.sortByDateDesc<CommentItem>(publicComments);
    }

    const userComments = await this.getUserComments(username);
    const mergedMap = new Map<string, CommentItem>();

    publicComments.forEach((item: CommentItem) => {
      mergedMap.set(item.id, item);
    });

    userComments
      .filter((item: CommentItem) => item.artifactId === artifactId)
      .forEach((item: CommentItem) => {
        if (!mergedMap.has(item.id) || !this.isApprovedStatus(item.status)) {
          mergedMap.set(item.id, item);
        }
      });

    return this.sortByDateDesc<CommentItem>(Array.from(mergedMap.values()));
  }

  async getCommentLikeSummary(commentId: string, username: string = ''): Promise<InteractionSummary> {
    if (!username) {
      return { active: false, count: 0 };
    }

    const comments = await this.getUserComments(username);
    const target = comments.find((item: CommentItem) => item.id === commentId);
    return {
      active: target?.likedByCurrentUser || false,
      count: target?.likeCount || 0
    };
  }

  async toggleCommentLike(commentId: string, username: string): Promise<InteractionSummary> {
    const body: EmptyRequestBody = {};
    const res = await HttpApi.post<ApiResponse<BackendLikeSummaryData>>(`/comments/${commentId}/likes`, body);
    if (res.code !== 200) {
      throw new Error(res.message || '评论点赞失败');
    }

    await this.syncProfileStats(username);
    return {
      active: !!res.data?.isLiked,
      count: this.toSummaryCount(res.data)
    };
  }

  async addComment(
    artifact: Artifact,
    username: string,
    content: string,
    parentId: string = '',
    replyTo: string = ''
  ): Promise<CommentResult> {
    const trimmed = content ? content.trim() : '';

    if (!trimmed) {
      return { ok: false, message: '评论内容不能为空' };
    }
    if (trimmed.length > 200) {
      return { ok: false, message: '评论请控制在 200 字以内' };
    }

    const body: BackendCommentBody = { content: trimmed };
    if (parentId) {
      body.parentId = parentId;
    }
    if (replyTo) {
      body.replyTo = replyTo;
    }

    try {
      const res = await HttpApi.post<ApiResponse<BackendCommentRecord>>(`/artifacts/${artifact.id}/comments`, body);
      if (res.code !== 200) {
        return { ok: false, message: res.message || '评论提交失败' };
      }
      await this.syncProfileStats(username);
      return { ok: true, message: res.message || '评论已提交' };
    } catch (error) {
      const err = error as Error;
      return { ok: false, message: err.message || '评论提交失败' };
    }
  }

  async getUserComments(username: string): Promise<CommentItem[]> {
    if (!username) {
      return [];
    }

    const records = await this.fetchUserCommentRecords(username);
    const comments = records.map((item: BackendCommentRecord) => this.mapComment(item, username));
    return this.sortByDateDesc<CommentItem>(comments);
  }

  async addUpload(context: common.UIAbilityContext, draft: UploadDraft): Promise<void> {
    if (!draft.artifactId) {
      throw new Error('文物编号不能为空');
    }

    await HttpApi.uploadFile(context, `/artifacts/${draft.artifactId}/uploads`, draft.imageUri, 'file');
    await this.syncProfileStats(draft.username);
  }

  async getUploads(username: string): Promise<UploadedPhotoItem[]> {
    if (!username) {
      return [];
    }

    const records = await this.fetchUploadRecords(username);
    return this.sortByDateDesc<UploadedPhotoItem>(await this.mapUploads(records));
  }

  async getPrivacy(username: string): Promise<PrivacySettings> {
    return PrivacyService.getUserPrivacy(username);
  }

  async savePrivacy(username: string, privacy: PrivacySettings): Promise<void> {
    await PrivacyService.updateMyPrivacy(username, privacy);
  }

  async getStats(username: string): Promise<UserInteractionStats> {
    const favorites = await this.getFavorites(username);
    const uploads = await this.getUploads(username);
    const comments = await this.getUserComments(username);

    let likes = 0;
    try {
      likes = (await this.getLikes(username)).length;
    } catch (error) {
      likes = 0;
    }

    let history = 0;
    try {
      history = (await this.getHistory(username)).length;
    } catch (error) {
      history = 0;
    }

    return {
      likes: likes,
      favorites: favorites.length,
      comments: comments.length,
      photos: uploads.length,
      history: history
    };
  }
}

export const interactionStore = new InteractionStore();

import common from '@ohos.app.ability.common';
import { Artifact } from '../models/Artifact';
import {
  CommentItem,
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
import { HttpApi, UploadFormField } from '../network/HttpApi';
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

interface DateSortable {
  createdAt?: string;
  viewedAt?: string;
  likedAt?: string;
}

interface EmptyRequestBody {
}

interface FavoriteRequestBody {
  artifactId: string;
  groupName: string;
}

interface HistoryRequestBody {
  artifactId: string;
}

interface CommentCreateRequestBody {
  content: string;
  parentId?: string;
  replyTo?: string;
}

interface PublicCommentProfileData {
  profileUsername: string;
  displayName: string;
  userId: string;
  avatar: string;
}

type RawValue = Object | Object[] | string | number | boolean | null | undefined;
type RawRecord = Record<string, RawValue>;

const BLOCKED_WORDS: string[] = ['广告', 'spam', '辱骂', '违法'];

class InteractionStore {
  private readonly favoriteGroupKey = 'pm.favoriteGroups';
  private readonly privacyKey = 'pm.privacy';
  private readonly likeSummaryCache = new Map<string, InteractionSummary>();
  private readonly favoriteSummaryCache = new Map<string, InteractionSummary>();

  private buildArtifactCacheKey(username: string, artifactId: string): string {
    return `${username || 'guest'}::${artifactId}`;
  }

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

    try {
      const stats = await this.getStats(username);
      AppStorage.SetOrCreate('profileLikes', stats.likes);
      AppStorage.SetOrCreate('profileFavorites', stats.favorites);
      AppStorage.SetOrCreate('profileComments', stats.comments);
      AppStorage.SetOrCreate('profilePhotos', stats.photos);
    } catch (error) {
      console.error(`[InteractionStore] syncProfileStats failed ${JSON.stringify(error)}`);
    }

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
      console.error(`[InteractionStore] read local config failed key=${key} error=${JSON.stringify(error)}`);
      return fallback;
    }
  }

  private async setJsonValue<T>(key: string, value: T): Promise<void> {
    await preferencesUtil.putString(key, JSON.stringify(value));
  }

  private mapToObject<K, V>(map: Map<K, V>): Record<string, V> {
    const obj: Record<string, V> = {};
    map.forEach((value: V, key: K) => {
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
      const trimmed = item.trim();
      if (!trimmed || seen.has(trimmed)) {
        return;
      }
      seen.add(trimmed);
      result.push(trimmed);
    });
    return result;
  }

  private async loadFavoriteGroups(username: string): Promise<string[]> {
    const groupObj = await this.getJsonValue<Record<string, string[]>>(this.favoriteGroupKey, {});
    const groupMap = this.objectToMap<string[]>(groupObj);
    const customGroups = username ? (groupMap.get(username) || []) : [];
    return this.uniqueStrings([...FAVORITE_GROUPS, ...customGroups]);
  }

  private async normalizeFavoriteGroupForUser(username: string, groupName: string): Promise<string> {
    const groups = await this.loadFavoriteGroups(username);
    return groups.indexOf(groupName) > -1 ? groupName : groups[0];
  }

  private normalizeFavoriteGroup(groupName: string): string {
    return FAVORITE_GROUPS.indexOf(groupName) > -1 ? groupName : FAVORITE_GROUPS[0];
  }

  private sortByDateDesc<T extends DateSortable>(items: T[]): T[] {
    return [...items].sort((left: T, right: T) => {
      const leftTime = new Date(left.createdAt || left.viewedAt || left.likedAt || '').getTime();
      const rightTime = new Date(right.createdAt || right.viewedAt || right.likedAt || '').getTime();
      return rightTime - leftTime;
    });
  }

  private readRecord(value: RawValue): RawRecord {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      return value as RawRecord;
    }
    return {};
  }

  private extractArray<T>(data: RawValue): T[] {
    if (Array.isArray(data)) {
      return data as T[];
    }

    const record = this.readRecord(data);
    if (Array.isArray(record['items'])) {
      return record['items'] as T[];
    }
    if (Array.isArray(record['records'])) {
      return record['records'] as T[];
    }
    if (Array.isArray(record['list'])) {
      return record['list'] as T[];
    }
    if (Array.isArray(record['content'])) {
      return record['content'] as T[];
    }
    return [];
  }

  private readString(record: RawRecord, keys: string[], fallback: string = ''): string {
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

  private readNumber(record: RawRecord, keys: string[], fallback: number = 0): number {
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
    return fallback;
  }

  private readBoolean(record: RawRecord, keys: string[], fallback: boolean = false): boolean {
    for (let index = 0; index < keys.length; index += 1) {
      const value = record[keys[index]];
      if (typeof value === 'boolean') {
        return value;
      }
      if (typeof value === 'number') {
        return value > 0;
      }
      if (typeof value === 'string') {
        const normalized = value.toLowerCase();
        if (normalized === 'true' || normalized === '1' || normalized === 'yes') {
          return true;
        }
        if (normalized === 'false' || normalized === '0' || normalized === 'no') {
          return false;
        }
      }
    }
    return fallback;
  }

  private toReviewStatus(value: RawValue): ReviewStatus {
    if (typeof value === 'number') {
      return value === 1 || value === 2 ? ReviewStatus.Approved : ReviewStatus.Pending;
    }
    if (typeof value === 'string') {
      const normalized = value.toUpperCase();
      if (normalized === 'APPROVED' || normalized === 'PASS' || normalized === 'PASSED' || normalized === 'SUCCESS') {
        return ReviewStatus.Approved;
      }
    }
    return ReviewStatus.Pending;
  }

  private extractCommentChildren(record: RawRecord): Object[] {
    if (Array.isArray(record['replies'])) {
      return record['replies'] as Object[];
    }
    if (Array.isArray(record['children'])) {
      return record['children'] as Object[];
    }
    if (Array.isArray(record['replyList'])) {
      return record['replyList'] as Object[];
    }
    if (Array.isArray(record['subComments'])) {
      return record['subComments'] as Object[];
    }
    return [];
  }

  private buildCommentProfile(
    record: RawRecord,
    fallbackUsername: string = '',
    fallbackDisplayName: string = ''
  ): PublicCommentProfileData {
    const profileUsername = this.readString(
      record,
      ['username', 'authorUsername', 'createBy', 'createdBy', 'account', 'loginName'],
      fallbackUsername
    );
    const displayName = this.readString(
      record,
      ['userName', 'nickname', 'nickName', 'authorName', 'displayName'],
      fallbackDisplayName || profileUsername || fallbackUsername
    );

    return {
      profileUsername: profileUsername,
      displayName: displayName || profileUsername || fallbackUsername || '匿名用户',
      userId: this.readString(record, ['userId', 'authorId', 'commentUserId'], ''),
      avatar: this.readString(record, ['avatar', 'userAvatar', 'authorAvatar'], '')
    };
  }

  private async getData<T>(url: string): Promise<T> {
    const response = await HttpApi.get<ApiResponse<T>>(url);
    if (response.code !== 200) {
      throw new Error(response.message || '请求失败');
    }
    return response.data;
  }

  private async postData<T>(url: string, body: object): Promise<T> {
    const response = await HttpApi.post<ApiResponse<T>>(url, body);
    if (response.code !== 200) {
      throw new Error(response.message || '请求失败');
    }
    return response.data;
  }

  private async deleteData<T>(url: string): Promise<T> {
    const response = await HttpApi.delete<ApiResponse<T>>(url);
    if (response.code !== 200) {
      throw new Error(response.message || '请求失败');
    }
    return response.data;
  }

  private mapFavoriteItem(data: Object): FavoriteItem {
    const record = this.readRecord(data);
    return {
      artifactId: this.readString(record, ['artifactId', 'objectId'], ''),
      title: this.readString(record, ['artifactTitle', 'title'], ''),
      imageUrl: this.readString(record, ['imageUrl', 'artifactImageUrl', 'photoUrl'], ''),
      period: this.readString(record, ['period'], ''),
      museum: this.readString(record, ['museum', 'museumName'], ''),
      groupName: this.readString(record, ['groupName'], this.getDefaultFavoriteGroup()),
      createdAt: this.readString(record, ['createTime', 'createdAt'], new Date().toISOString())
    };
  }

  private mapLikeItem(data: Object): LikeItem {
    const record = this.readRecord(data);
    return {
      artifactId: this.readString(record, ['artifactId', 'objectId'], ''),
      title: this.readString(record, ['artifactTitle', 'title'], ''),
      imageUrl: this.readString(record, ['imageUrl', 'artifactImageUrl', 'photoUrl'], ''),
      period: this.readString(record, ['period'], ''),
      museum: this.readString(record, ['museum', 'museumName'], ''),
      likedAt: this.readString(record, ['likedAt', 'createTime', 'createdAt'], new Date().toISOString())
    };
  }

  private mapHistoryItem(data: Object): HistoryItem {
    const record = this.readRecord(data);
    return {
      artifactId: this.readString(record, ['artifactId', 'objectId'], ''),
      title: this.readString(record, ['artifactTitle', 'title'], ''),
      imageUrl: this.readString(record, ['imageUrl', 'artifactImageUrl', 'photoUrl'], ''),
      period: this.readString(record, ['period'], ''),
      museum: this.readString(record, ['museum', 'museumName'], ''),
      viewedAt: this.readString(record, ['viewTime', 'viewedAt', 'createTime', 'createdAt'], new Date().toISOString())
    };
  }

  private mapCommentItem(
    data: Object,
    fallbackArtifactId: string = '',
    fallbackStatus: ReviewStatus = ReviewStatus.Pending,
    fallbackUsername: string = '',
    fallbackDisplayName: string = '',
    fallbackParentId: string = '',
    fallbackReplyTo: string = ''
  ): CommentItem {
    const record = this.readRecord(data);
    const commentId = this.readString(record, ['commentId', 'objectId', 'id'], '');
    const rawStatus = record['status'] || record['reviewStatus'] || record['auditStatus'];
    const status = rawStatus !== undefined && rawStatus !== null
      ? this.toReviewStatus(rawStatus)
      : fallbackStatus;
    const profile = this.buildCommentProfile(record, fallbackUsername, fallbackDisplayName);
    return {
      id: commentId,
      artifactId: this.readString(record, ['artifactId', 'artifactObjectId'], fallbackArtifactId),
      artifactTitle: this.readString(record, ['artifactTitle', 'title'], ''),
      username: profile.profileUsername || profile.displayName,
      displayName: profile.displayName,
      profileUsername: profile.profileUsername,
      userId: profile.userId,
      avatar: profile.avatar,
      content: this.readString(record, ['content', 'commentContent'], ''),
      createdAt: this.readString(record, ['createTime', 'createdAt'], new Date().toISOString()),
      status: status,
      parentId: this.readString(
        record,
        ['parentId', 'parentCommentId', 'rootCommentId', 'rootId', 'replyCommentId'],
        fallbackParentId
      ),
      replyTo: this.readString(
        record,
        ['replyTo', 'replyToUsername', 'replyUserName', 'targetUsername', 'targetUserName', 'replyNickname'],
        fallbackReplyTo
      ),
      likeCount: this.readNumber(record, ['likeCount', 'likes'], 0),
      likedByCurrentUser: this.readBoolean(record, ['isLiked', 'likedByCurrentUser', 'liked'], false)
    };
  }

  private flattenCommentItems(
    data: Object,
    fallbackArtifactId: string = '',
    fallbackStatus: ReviewStatus = ReviewStatus.Pending,
    fallbackUsername: string = '',
    fallbackDisplayName: string = '',
    fallbackParentId: string = '',
    fallbackReplyTo: string = ''
  ): CommentItem[] {
    const current = this.mapCommentItem(
      data,
      fallbackArtifactId,
      fallbackStatus,
      fallbackUsername,
      fallbackDisplayName,
      fallbackParentId,
      fallbackReplyTo
    );
    if (!current.id) {
      return [];
    }

    const items: CommentItem[] = [current];
    const children = this.extractCommentChildren(this.readRecord(data));
    const childReplyTarget = current.displayName || current.username;
    children.forEach((child: Object) => {
      const childItems = this.flattenCommentItems(
        child,
        current.artifactId || fallbackArtifactId,
        fallbackStatus,
        '',
        '',
        current.id,
        childReplyTarget
      );
      childItems.forEach((item: CommentItem) => items.push(item));
    });
    return items;
  }

  private mapUploadItem(data: Object): UploadedPhotoItem {
    const record = this.readRecord(data);
    return {
      id: this.readString(record, ['uploadId', 'objectId', 'id'], ''),
      artifactId: this.readString(record, ['artifactId', 'objectId'], ''),
      artifactTitle: this.readString(record, ['artifactTitle', 'title'], ''),
      username: this.readString(record, ['username', 'nickname'], ''),
      imageUri: this.readString(record, ['imageUrl', 'photoUrl', 'imagePath', 'imageUri'], ''),
      location: this.readString(record, ['location'], ''),
      description: this.readString(record, ['description'], ''),
      createdAt: this.readString(record, ['createTime', 'createdAt'], new Date().toISOString()),
      status: this.toReviewStatus(record['status'] || record['reviewStatus'] || record['auditStatus'])
    };
  }

  private mapInteractionSummary(
    data: RawValue,
    activeKeys: string[],
    countKeys: string[],
    fallbackActive: boolean,
    fallbackCount: number
  ): InteractionSummary {
    const record = this.readRecord(data);
    return {
      active: this.readBoolean(record, activeKeys, fallbackActive),
      count: this.readNumber(record, countKeys, fallbackCount)
    };
  }

  private updateLikeSummaryCache(username: string, artifactId: string, summary: InteractionSummary): void {
    this.likeSummaryCache.set(this.buildArtifactCacheKey(username, artifactId), summary);
  }

  private updateFavoriteSummaryCache(username: string, artifactId: string, summary: InteractionSummary): void {
    this.favoriteSummaryCache.set(this.buildArtifactCacheKey(username, artifactId), summary);
  }

  private async fetchFavoriteList(username: string): Promise<FavoriteItem[]> {
    const data = await this.getData<RawValue>(`/users/${username}/favorites`);
    return this.sortByDateDesc(
      this.extractArray<Object>(data)
        .map((item: Object) => this.mapFavoriteItem(item))
        .filter((item: FavoriteItem) => !!item.artifactId)
    );
  }

  private async fetchLikeList(username: string): Promise<LikeItem[]> {
    const data = await this.getData<RawValue>(`/users/${username}/likes`);
    return this.sortByDateDesc(
      this.extractArray<Object>(data)
        .map((item: Object) => this.mapLikeItem(item))
        .filter((item: LikeItem) => !!item.artifactId)
    );
  }

  private async fetchUserCommentList(username: string): Promise<CommentItem[]> {
    const data = await this.getData<RawValue>(`/users/${username}/comments`);
    return this.sortByDateDesc(
      this.extractArray<Object>(data)
        .map((item: Object) => this.mapCommentItem(item, '', ReviewStatus.Pending, username, username))
        .filter((item: CommentItem) => !!item.id)
    );
  }

  async getLikeSummary(artifactId: string, username: string = ''): Promise<InteractionSummary> {
    const cacheKey = this.buildArtifactCacheKey(username, artifactId);
    const cached = this.likeSummaryCache.get(cacheKey);
    if (cached) {
      return cached;
    }

    if (!username) {
      const emptySummary: InteractionSummary = { active: false, count: 0 };
      return emptySummary;
    }

    try {
      const likes = await this.fetchLikeList(username);
      const active = likes.some((item: LikeItem) => item.artifactId === artifactId);
      const summary: InteractionSummary = {
        active: active,
        count: active ? 1 : 0
      };
      this.updateLikeSummaryCache(username, artifactId, summary);
      return summary;
    } catch (error) {
      console.error(`[InteractionStore] getLikeSummary failed artifactId=${artifactId} ${JSON.stringify(error)}`);
      const emptySummary: InteractionSummary = { active: false, count: 0 };
      return emptySummary;
    }
  }

  async toggleLike(artifactId: string, username: string, artifact?: Artifact): Promise<InteractionSummary> {
    if (!username) {
      throw new Error('请先登录');
    }

    const current = await this.getLikeSummary(artifactId, username);
    let nextSummary: InteractionSummary;

    if (current.active) {
      const data = await this.deleteData<RawValue>(`/artifacts/${artifactId}/likes`);
      nextSummary = this.mapInteractionSummary(data, ['isLiked'], ['likeCount', 'count'], false, 0);
    } else {
      const body: EmptyRequestBody = {};
      const data = await this.postData<RawValue>(`/artifacts/${artifactId}/likes`, body);
      nextSummary = this.mapInteractionSummary(data, ['isLiked'], ['likeCount', 'count'], true, Math.max(current.count, 0) + 1);
    }

    this.updateLikeSummaryCache(username, artifactId, nextSummary);
    await this.syncProfileStats(username);
    return nextSummary;
  }

  async getLikes(username: string): Promise<LikeItem[]> {
    if (!username) {
      return [];
    }

    try {
      return await this.fetchLikeList(username);
    } catch (error) {
      console.error(`[InteractionStore] getLikes failed username=${username} ${JSON.stringify(error)}`);
      return [];
    }
  }

  async removeLike(artifactId: string, username: string): Promise<void> {
    if (!username) {
      return;
    }

    const data = await this.deleteData<RawValue>(`/artifacts/${artifactId}/likes`);
    const summary = this.mapInteractionSummary(data, ['isLiked'], ['likeCount', 'count'], false, 0);
    this.updateLikeSummaryCache(username, artifactId, summary);
    await this.syncProfileStats(username);
  }

  async getFavoriteSummary(artifactId: string, username: string = ''): Promise<InteractionSummary> {
    const cacheKey = this.buildArtifactCacheKey(username, artifactId);
    const cached = this.favoriteSummaryCache.get(cacheKey);
    if (cached) {
      return cached;
    }

    if (!username) {
      const emptySummary: InteractionSummary = { active: false, count: 0 };
      return emptySummary;
    }

    try {
      const favorites = await this.fetchFavoriteList(username);
      const active = favorites.some((item: FavoriteItem) => item.artifactId === artifactId);
      const summary: InteractionSummary = {
        active: active,
        count: active ? 1 : 0
      };
      this.updateFavoriteSummaryCache(username, artifactId, summary);
      return summary;
    } catch (error) {
      console.error(`[InteractionStore] getFavoriteSummary failed artifactId=${artifactId} ${JSON.stringify(error)}`);
      const emptySummary: InteractionSummary = { active: false, count: 0 };
      return emptySummary;
    }
  }

  async toggleFavorite(
    artifact: Artifact,
    username: string,
    groupName: string = FAVORITE_GROUPS[0]
  ): Promise<InteractionSummary> {
    if (!username) {
      throw new Error('请先登录');
    }

    const current = await this.getFavoriteSummary(artifact.id, username);
    let nextSummary: InteractionSummary;

    if (current.active) {
      const data = await this.deleteData<RawValue>(`/users/${username}/favorites/${artifact.id}`);
      nextSummary = this.mapInteractionSummary(data, ['isFavorited'], ['favoriteCount', 'count'], false, 0);
    } else {
      const normalizedGroup = await this.normalizeFavoriteGroupForUser(username, groupName);
      const body: FavoriteRequestBody = {
        artifactId: artifact.id,
        groupName: normalizedGroup
      };
      const data = await this.postData<RawValue>(`/users/${username}/favorites`, body);
      nextSummary = this.mapInteractionSummary(data, ['isFavorited'], ['favoriteCount', 'count'], true, 1);
    }

    this.updateFavoriteSummaryCache(username, artifact.id, nextSummary);
    await this.syncProfileStats(username);
    return nextSummary;
  }

  async getFavorites(username: string): Promise<FavoriteItem[]> {
    if (!username) {
      return [];
    }

    try {
      const favorites = await this.fetchFavoriteList(username);
      const groups = await this.loadFavoriteGroups(username);
      const fallbackGroup = groups.length > 0 ? groups[0] : this.getDefaultFavoriteGroup();
      return favorites.map((item: FavoriteItem): FavoriteItem => {
        const nextGroup = item.groupName ? item.groupName : fallbackGroup;
        this.updateFavoriteSummaryCache(username, item.artifactId, { active: true, count: 1 });
        return {
          artifactId: item.artifactId,
          title: item.title,
          imageUrl: item.imageUrl,
          period: item.period,
          museum: item.museum,
          groupName: groups.indexOf(nextGroup) > -1 ? nextGroup : fallbackGroup,
          createdAt: item.createdAt
        };
      });
    } catch (error) {
      console.error(`[InteractionStore] getFavorites failed username=${username} ${JSON.stringify(error)}`);
      return [];
    }
  }

  async getFavoriteGroups(username: string): Promise<string[]> {
    return this.loadFavoriteGroups(username);
  }

  async addFavoriteGroup(username: string, groupName: string): Promise<string[]> {
    const trimmed = groupName.trim();
    if (!username || !trimmed) {
      return this.loadFavoriteGroups(username);
    }
    const groupObj = await this.getJsonValue<Record<string, string[]>>(this.favoriteGroupKey, {});
    const groupMap = this.objectToMap<string[]>(groupObj);
    const currentGroups = groupMap.get(username) || [];
    groupMap.set(username, this.uniqueStrings([...currentGroups, trimmed]));
    await this.setJsonValue(this.favoriteGroupKey, this.mapToObject(groupMap));
    return this.loadFavoriteGroups(username);
  }

  async deleteFavoriteGroup(username: string, groupName: string): Promise<string[]> {
    if (!username || FAVORITE_GROUPS.indexOf(groupName) > -1) {
      return this.loadFavoriteGroups(username);
    }

    const favorites = await this.getFavorites(username);
    const nextGroups = (await this.loadFavoriteGroups(username)).filter((item: string) => item !== groupName);
    const fallbackGroup = nextGroups.length > 0 ? nextGroups[0] : this.getDefaultFavoriteGroup();

    for (let index = 0; index < favorites.length; index += 1) {
      const favorite = favorites[index];
      if (favorite.groupName === groupName) {
        await this.moveFavoriteToGroup(favorite.artifactId, username, fallbackGroup);
      }
    }

    const groupObj = await this.getJsonValue<Record<string, string[]>>(this.favoriteGroupKey, {});
    const groupMap = this.objectToMap<string[]>(groupObj);
    const customGroups = nextGroups.filter((item: string) => FAVORITE_GROUPS.indexOf(item) === -1);
    groupMap.set(username, customGroups);
    await this.setJsonValue(this.favoriteGroupKey, this.mapToObject(groupMap));
    await this.syncProfileStats(username);
    return this.loadFavoriteGroups(username);
  }

  async getFavoriteGroupForArtifact(username: string, artifactId: string): Promise<string> {
    const favorites = await this.getFavorites(username);
    const target = favorites.find((item: FavoriteItem) => item.artifactId === artifactId);
    const groups = await this.loadFavoriteGroups(username);
    return target ? target.groupName : (groups.length > 0 ? groups[0] : this.getDefaultFavoriteGroup());
  }

  async getFavoriteGroupSummaries(username: string): Promise<FavoriteGroupSummary[]> {
    const favorites = await this.getFavorites(username);
    const groups = await this.loadFavoriteGroups(username);
    return groups.map((groupName: string): FavoriteGroupSummary => {
      return {
        name: groupName,
        count: favorites.filter((item: FavoriteItem) => item.groupName === groupName).length,
        isDefault: FAVORITE_GROUPS.indexOf(groupName) > -1
      };
    });
  }

  async moveFavoriteToGroup(artifactId: string, username: string, groupName: string): Promise<string> {
    if (!username) {
      return this.getDefaultFavoriteGroup();
    }

    const normalizedGroup = await this.normalizeFavoriteGroupForUser(username, groupName);
    const body: FavoriteRequestBody = {
      artifactId: artifactId,
      groupName: normalizedGroup
    };
    await this.postData<RawValue>(`/users/${username}/favorites`, body);
    const summary: InteractionSummary = { active: true, count: 1 };
    this.updateFavoriteSummaryCache(username, artifactId, summary);
    return normalizedGroup;
  }

  async cycleFavoriteGroup(artifactId: string, username: string): Promise<string> {
    const groups = await this.loadFavoriteGroups(username);
    const currentGroup = await this.getFavoriteGroupForArtifact(username, artifactId);
    const currentIndex = groups.indexOf(currentGroup);
    const nextIndex = currentIndex > -1 ? (currentIndex + 1) % groups.length : 0;
    return this.moveFavoriteToGroup(artifactId, username, groups[nextIndex]);
  }

  async removeFavorite(artifactId: string, username: string): Promise<void> {
    if (!username) {
      return;
    }

    await this.deleteData<RawValue>(`/users/${username}/favorites/${artifactId}`);
    this.updateFavoriteSummaryCache(username, artifactId, { active: false, count: 0 });
    await this.syncProfileStats(username);
  }

  async recordHistory(artifact: Artifact, username: string): Promise<void> {
    if (!username || !artifact || !artifact.id) {
      return;
    }

    try {
      const body: HistoryRequestBody = {
        artifactId: artifact.id
      };
      await this.postData<RawValue>(`/users/${username}/history`, body);
    } catch (error) {
      console.error(`[InteractionStore] recordHistory failed artifactId=${artifact.id} ${JSON.stringify(error)}`);
    }
  }

  async getHistory(username: string): Promise<HistoryItem[]> {
    if (!username) {
      return [];
    }

    try {
      const data = await this.getData<RawValue>(`/users/${username}/history`);
      return this.sortByDateDesc(
        this.extractArray<Object>(data)
          .map((item: Object) => this.mapHistoryItem(item))
          .filter((item: HistoryItem) => !!item.artifactId)
      );
    } catch (error) {
      console.error(`[InteractionStore] getHistory failed username=${username} ${JSON.stringify(error)}`);
      return [];
    }
  }

  async getCommentsForArtifact(artifactId: string, username: string = ''): Promise<CommentItem[]> {
    try {
      const data = await this.getData<RawValue>(`/artifacts/${artifactId}/comments`);
      const publicComments: CommentItem[] = [];
      this.extractArray<Object>(data).forEach((item: Object) => {
        const flattenedItems = this.flattenCommentItems(item, artifactId, ReviewStatus.Approved);
        flattenedItems.forEach((comment: CommentItem) => {
          if (comment.id) {
            publicComments.push(comment);
          }
        });
      });

      if (!username) {
        return this.sortByDateDesc(publicComments);
      }

      const ownComments = (await this.getUserComments(username))
        .filter((item: CommentItem) => item.artifactId === artifactId && item.status !== ReviewStatus.Approved);

      const commentMap = new Map<string, CommentItem>();
      publicComments.forEach((item: CommentItem) => commentMap.set(item.id, item));
      ownComments.forEach((item: CommentItem) => commentMap.set(item.id, item));
      return this.sortByDateDesc(Array.from(commentMap.values()));
    } catch (error) {
      console.error(`[InteractionStore] getCommentsForArtifact failed artifactId=${artifactId} ${JSON.stringify(error)}`);
      return [];
    }
  }

  async getCommentLikeSummary(commentId: string, username: string = ''): Promise<InteractionSummary> {
    return {
      active: false,
      count: 0
    };
  }

  async toggleCommentLike(commentId: string, username: string): Promise<InteractionSummary> {
    if (!username) {
      throw new Error('请先登录');
    }

    const body: EmptyRequestBody = {};
    const data = await this.postData<RawValue>(`/comments/${commentId}/likes`, body);
    await this.syncProfileStats(username);
    return this.mapInteractionSummary(data, ['isLiked'], ['likeCount', 'count'], true, 1);
  }

  async addComment(
    artifact: Artifact,
    username: string,
    content: string,
    parentId: string = '',
    replyTo: string = ''
  ): Promise<CommentResult> {
    const trimmed = content.trim();
    if (!trimmed) {
      return { ok: false, message: '评论内容不能为空' };
    }
    if (trimmed.length < 2) {
      return { ok: false, message: '评论至少输入 2 个字' };
    }
    if (trimmed.length > 200) {
      return { ok: false, message: '评论请控制在 200 字以内' };
    }
    if (BLOCKED_WORDS.some((word: string) => trimmed.indexOf(word) > -1)) {
      return { ok: false, message: '评论包含敏感词，请修改后再试' };
    }
    if (!username) {
      return { ok: false, message: '请先登录' };
    }

    const body: CommentCreateRequestBody = {
      content: trimmed
    };
    if (parentId) {
      body.parentId = parentId;
    }
    if (replyTo) {
      body.replyTo = replyTo;
    }

    try {
      await this.postData<RawValue>(`/artifacts/${artifact.id}/comments`, body as object);
      await this.syncProfileStats(username);
      return { ok: true, message: '评论已提交，等待审核' };
    } catch (error) {
      const err = error as Error;
      return { ok: false, message: err.message || '评论提交失败' };
    }
  }

  async getUserComments(username: string): Promise<CommentItem[]> {
    if (!username) {
      return [];
    }

    try {
      return await this.fetchUserCommentList(username);
    } catch (error) {
      console.error(`[InteractionStore] getUserComments failed username=${username} ${JSON.stringify(error)}`);
      return [];
    }
  }

  async addUpload(context: common.UIAbilityContext, draft: UploadDraft): Promise<void> {
    if (!draft.username) {
      throw new Error('请先登录');
    }

    const data: UploadFormField[] = [];
    if (draft.location.trim()) {
      data.push({ name: 'location', value: draft.location.trim() });
    }
    if (draft.description.trim()) {
      data.push({ name: 'description', value: draft.description.trim() });
    }

    await HttpApi.uploadFile(
      context,
      `/artifacts/${draft.artifactId}/uploads`,
      draft.imageUri,
      'file',
      data
    );
    await this.syncProfileStats(draft.username);
  }

  async getUploads(username: string): Promise<UploadedPhotoItem[]> {
    if (!username) {
      return [];
    }

    try {
      const data = await this.getData<RawValue>(`/users/${username}/uploads`);
      return this.sortByDateDesc(
        this.extractArray<Object>(data)
          .map((item: Object) => this.mapUploadItem(item))
          .filter((item: UploadedPhotoItem) => !!item.id)
      );
    } catch (error) {
      console.error(`[InteractionStore] getUploads failed username=${username} ${JSON.stringify(error)}`);
      return [];
    }
  }

  async getPrivacy(username: string): Promise<PrivacySettings> {
    if (!username) {
      return {
        showFavorites: true,
        showLikes: true,
        showComments: true,
        showPhotos: true
      };
    }

    const privacyObj = await this.getJsonValue<Record<string, PrivacySettings>>(this.privacyKey, {});
    const privacyMap = this.objectToMap<PrivacySettings>(privacyObj);
    const saved = privacyMap.get(username);

    if (!saved) {
      return {
        showFavorites: true,
        showLikes: true,
        showComments: true,
        showPhotos: true
      };
    }

    return {
      showFavorites: saved.showFavorites,
      showLikes: saved.showLikes,
      showComments: saved.showComments,
      showPhotos: saved.showPhotos
    };
  }

  async savePrivacy(username: string, privacy: PrivacySettings): Promise<void> {
    if (!username) {
      throw new Error('[InteractionStore] savePrivacy failed: username is empty');
    }

    const privacyObj = await this.getJsonValue<Record<string, PrivacySettings>>(this.privacyKey, {});
    const privacyMap = this.objectToMap<PrivacySettings>(privacyObj);

    privacyMap.set(username, {
      showFavorites: privacy.showFavorites,
      showLikes: privacy.showLikes,
      showComments: privacy.showComments,
      showPhotos: privacy.showPhotos
    });

    await this.setJsonValue(this.privacyKey, this.mapToObject(privacyMap));
  }

  async getStats(username: string): Promise<UserInteractionStats> {
    const favorites = await this.getFavorites(username);
    const uploads = await this.getUploads(username);
    const comments = await this.getUserComments(username);
    const history = await this.getHistory(username);
    const likes = await this.getLikes(username);

    return {
      likes: likes.length,
      favorites: favorites.length,
      comments: comments.length,
      photos: uploads.length,
      history: history.length
    };
  }
}

export const interactionStore = new InteractionStore();

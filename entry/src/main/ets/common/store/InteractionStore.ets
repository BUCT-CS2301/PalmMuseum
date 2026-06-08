import { Artifact } from '../models/Artifact';
import {
  CommentItem,
  CreatedAtItem,
  DEFAULT_PRIVACY_SETTINGS,
  FAVORITE_GROUPS,
  FavoriteGroupSummary,
  FavoriteItem,
  HistoryItem,
  InteractionSummary,
  LikeItem,          // 新增导入
  PrivacySettings,
  ReviewStatus,
  UploadedPhotoItem,
  UploadDraft,
  UserInteractionStats
} from '../models/InteractionModels';
import { preferencesUtil } from '../utils/PreferencesUtil';

interface CommentResult {
  ok: boolean;
  message: string;
}

const BLOCKED_WORDS: string[] = ['广告', 'spam', '辱骂', '违法'];
const MAX_HISTORY = 20;
const COMMENT_REVIEW_DELAY_MS = 1500;

class InteractionStore {
  private readonly likeKey = 'pm.likes';
  private readonly likeItemsKey = 'pm.likeItems';
  private readonly likeCountBaseKey = 'pm.likeCountBase';
  private readonly favoriteKey = 'pm.favorites';
  private readonly favoriteRemovedKey = 'pm.favoriteRemoved';
  private readonly publicFavoriteCacheKey = 'pm.publicFavorites';
  private readonly publicLikeCacheKey = 'pm.publicLikes';
  private readonly publicCommentCacheKey = 'pm.publicComments';
  private readonly publicUploadCacheKey = 'pm.publicUploads';
  private readonly favoriteGroupKey = 'pm.favoriteGroups';
  private readonly commentKey = 'pm.comments';
  private readonly commentLikeKey = 'pm.commentLikes';
  private readonly uploadKey = 'pm.uploads';
  private readonly historyKey = 'pm.history';
  private readonly privacyKey = 'pm.privacy';

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
      console.error(`读取本地交互数据失败: ${key} ${JSON.stringify(error)}`);
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

  private normalizeCacheKeys(items: string[]): string[] {
    const keys: string[] = [];
    items.forEach((item: string) => {
      const trimmed = item ? item.trim() : '';
      if (trimmed && keys.indexOf(trimmed) === -1) {
        keys.push(trimmed);
      }
    });
    return keys;
  }

  private getPublicCacheKeys(username: string): string[] {
    const currentUsername = AppStorage.Get('username') as string || '';
    const currentNickname = AppStorage.Get('nickname') as string || '';
    const keys: string[] = [username];
    if (currentUsername && (currentUsername === username || currentNickname === username)) {
      keys.push(currentUsername);
      keys.push(currentNickname);
    }
    return this.normalizeCacheKeys(keys);
  }

  private async getPublicCachedItems<T>(storageKey: string, aliases: string[]): Promise<T[]> {
    const lookupKeys = this.normalizeCacheKeys(aliases);
    if (lookupKeys.length === 0) {
      return [];
    }
    const cacheObj = await this.getJsonValue<Record<string, T[]>>(storageKey, {});
    const cacheMap = this.objectToMap<T[]>(cacheObj);
    for (let index = 0; index < lookupKeys.length; index += 1) {
      const items = cacheMap.get(lookupKeys[index]);
      if (items && items.length > 0) {
        return items;
      }
    }
    return [];
  }

  private async syncPublicLikesCache(username: string): Promise<void> {
    if (!username) {
      return;
    }
    await this.savePublicLikes(username, await this.getLikes(username));
  }

  private async syncPublicFavoritesCache(username: string): Promise<void> {
    if (!username) {
      return;
    }
    await this.savePublicFavorites(username, await this.getFavorites(username));
  }

  private async syncPublicCommentsCache(username: string): Promise<void> {
    if (!username) {
      return;
    }
    await this.savePublicComments(username, await this.getUserComments(username));
  }

  private async syncPublicUploadsCache(username: string): Promise<void> {
    if (!username) {
      return;
    }
    await this.savePublicUploads(username, await this.getUploads(username));
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

  private async getFavoriteRemovedMap(): Promise<Map<string, string[]>> {
    const removedObj = await this.getJsonValue<Record<string, string[]>>(this.favoriteRemovedKey, {});
    return this.objectToMap<string[]>(removedObj);
  }

  private async markFavoriteRemoved(username: string, artifactId: string, removed: boolean): Promise<void> {
    if (!username || !artifactId) {
      return;
    }
    const removedMap = await this.getFavoriteRemovedMap();
    const current = removedMap.get(username) || [];
    const next = current.filter((item: string) => item !== artifactId);
    if (removed) {
      next.unshift(artifactId);
    }
    removedMap.set(username, next);
    await this.setJsonValue(this.favoriteRemovedKey, this.mapToObject(removedMap));
  }

  private async normalizeFavoriteGroupForUser(username: string, groupName: string): Promise<string> {
    const groups = await this.loadFavoriteGroups(username);
    return groups.indexOf(groupName) > -1 ? groupName : groups[0];
  }

  private normalizeFavoriteGroup(groupName: string): string {
    return FAVORITE_GROUPS.indexOf(groupName) > -1 ? groupName : FAVORITE_GROUPS[0];
  }

  private sortByDateDesc<T extends CreatedAtItem>(items: T[]): T[] {
    return [...items].sort((left: T, right: T) => {
      const leftTime = new Date(left.createdAt).getTime();
      const rightTime = new Date(right.createdAt).getTime();
      return rightTime - leftTime;
    });
  }

  private buildLikeBaseCount(artifactId: string): number {
    const seed = Number(artifactId);
    return Number.isNaN(seed) ? 16 : 16 + seed * 5;
  }

  private buildFavoriteBaseCount(artifactId: string): number {
    const seed = Number(artifactId);
    return Number.isNaN(seed) ? 8 : 8 + seed * 3;
  }

  private buildCommentBaseCount(commentId: string): number {
    if (!commentId.startsWith('seed-')) {
      return 0;
    }
    let total = 0;
    for (let index = 0; index < commentId.length; index += 1) {
      total += commentId.charCodeAt(index);
    }
    return 2 + total % 5;
  }

  private cloneCommentItem(item: CommentItem): CommentItem {
    const cloned: CommentItem = {
      id: item.id,
      artifactId: item.artifactId,
      artifactTitle: item.artifactTitle,
      username: item.username,
      content: item.content,
      createdAt: item.createdAt,
      status: item.status
    };
    if (item.parentId) {
      cloned.parentId = item.parentId;
    }
    if (item.replyTo) {
      cloned.replyTo = item.replyTo;
    }
    if (item.likeCount !== undefined) {
      cloned.likeCount = item.likeCount;
    }
    if (item.likedByCurrentUser !== undefined) {
      cloned.likedByCurrentUser = item.likedByCurrentUser;
    }
    return cloned;
  }

  private async saveCommentRecord(record: CommentItem, username: string): Promise<void> {
    const comments = await this.getJsonValue<CommentItem[]>(this.commentKey, []);
    comments.unshift(this.cloneCommentItem(record));
    await this.setJsonValue(this.commentKey, comments);
    await this.syncProfileStats(username);
  }

  private shouldAutoApproveComment(item: CommentItem): boolean {
    if (item.status !== ReviewStatus.Pending) {
      return false;
    }
    const createdTime = new Date(item.createdAt).getTime();
    if (Number.isNaN(createdTime)) {
      return true;
    }
    return Date.now() - createdTime >= COMMENT_REVIEW_DELAY_MS;
  }

  private async syncCommentReviewStatus(comments: CommentItem[]): Promise<CommentItem[]> {
    let changed = false;
    const synced: CommentItem[] = comments.map((item: CommentItem): CommentItem => {
      const nextItem = this.cloneCommentItem(item);
      if (this.shouldAutoApproveComment(nextItem)) {
        nextItem.status = ReviewStatus.Approved;
        changed = true;
      }
      return nextItem;
    });
    if (changed) {
      await this.setJsonValue(this.commentKey, synced);
    }
    return synced;
  }

  private cloneUploadItem(item: UploadedPhotoItem): UploadedPhotoItem {
    return {
      id: item.id,
      artifactId: item.artifactId,
      artifactTitle: item.artifactTitle,
      username: item.username,
      imageUri: item.imageUri,
      location: item.location,
      description: item.description,
      createdAt: item.createdAt,
      status: item.status
    };
  }

  private shouldAutoApproveUpload(item: UploadedPhotoItem): boolean {
    if (item.status !== ReviewStatus.Pending) {
      return false;
    }
    const createdTime = new Date(item.createdAt).getTime();
    if (Number.isNaN(createdTime)) {
      return true;
    }
    return Date.now() - createdTime >= COMMENT_REVIEW_DELAY_MS;
  }

  private async syncUploadReviewStatus(items: UploadedPhotoItem[]): Promise<UploadedPhotoItem[]> {
    let changed = false;
    const synced: UploadedPhotoItem[] = items.map((item: UploadedPhotoItem): UploadedPhotoItem => {
      const nextItem = this.cloneUploadItem(item);
      if (this.shouldAutoApproveUpload(nextItem)) {
        nextItem.status = ReviewStatus.Approved;
        changed = true;
      }
      return nextItem;
    });
    if (changed) {
      await this.setJsonValue(this.uploadKey, synced);
    }
    return synced;
  }

  private getSeedComments(artifactId: string): CommentItem[] {
    return [
      {
        id: `seed-${artifactId}-1`,
        artifactId: artifactId,
        artifactTitle: '',
        username: '文博爱好者',
        content: '文物信息很完整，配合语音讲解一起看体验更好。',
        createdAt: '2026-05-10T10:00:00.000Z',
        status: ReviewStatus.Approved
      },
      {
        id: `seed-${artifactId}-2`,
        artifactId: artifactId,
        artifactTitle: '',
        username: '海外馆藏观察员',
        content: '如果能补充同年代关联文物，会更方便横向比较。',
        createdAt: '2026-05-12T14:30:00.000Z',
        status: ReviewStatus.Approved
      }
    ];
  }

  private buildFavoriteItem(artifact: Artifact, groupName: string): FavoriteItem {
    return {
      artifactId: artifact.id,
      title: artifact.title,
      imageUrl: artifact.imageUrl,
      period: artifact.period,
      museum: artifact.museum,
      groupName: groupName,
      createdAt: new Date().toISOString()
    };
  }

  private cloneFavoriteItem(item: FavoriteItem): FavoriteItem {
    return {
      artifactId: item.artifactId,
      title: item.title,
      imageUrl: item.imageUrl,
      period: item.period,
      museum: item.museum,
      groupName: item.groupName,
      createdAt: item.createdAt
    };
  }

  private buildHistoryItem(artifact: Artifact): HistoryItem {
    return {
      artifactId: artifact.id,
      title: artifact.title,
      imageUrl: artifact.imageUrl,
      period: artifact.period,
      museum: artifact.museum,
      viewedAt: new Date().toISOString()
    };
  }

  // 新增：构建 LikeItem 快照
  private buildLikeItem(artifact: Artifact): LikeItem {
    return {
      artifactId: artifact.id,
      title: artifact.title,
      imageUrl: artifact.imageUrl,
      period: artifact.period,
      museum: artifact.museum,
      likedAt: new Date().toISOString()
    };
  }

  private async getCommentLikeMap(): Promise<Map<string, string[]>> {
    const commentLikeObj = await this.getJsonValue<Record<string, string[]>>(this.commentLikeKey, {});
    return this.objectToMap<string[]>(commentLikeObj);
  }

  private async enrichComments(items: CommentItem[], username: string = ''): Promise<CommentItem[]> {
    const likeMap = await this.getCommentLikeMap();
    return items.map((item: CommentItem) => {
      const users = likeMap.get(item.id) || [];
      const enriched = this.cloneCommentItem(item);
      enriched.likeCount = this.buildCommentBaseCount(item.id) + users.length;
      enriched.likedByCurrentUser = username ? users.indexOf(username) > -1 : false;
      return enriched;
    });
  }

  async getLikeSummary(artifactId: string, username: string = ''): Promise<InteractionSummary> {
    const likeObj = await this.getJsonValue<Record<string, string[]>>(this.likeKey, {});
    const likeMap = this.objectToMap<string[]>(likeObj);
    const users = likeMap.get(artifactId) || [];
    const likeCountBaseObj = await this.getJsonValue<Record<string, number>>(this.likeCountBaseKey, {});
    const likeCountBaseMap = this.objectToMap<number>(likeCountBaseObj);
    const cachedBase = likeCountBaseMap.get(artifactId);
    const countBase = cachedBase !== undefined ? cachedBase : this.buildLikeBaseCount(artifactId);
    return {
      active: username ? users.indexOf(username) > -1 : false,
      count: countBase + users.length
    };
  }

  async setLikeCount(artifactId: string, totalCount: number): Promise<void> {
    const likeObj = await this.getJsonValue<Record<string, string[]>>(this.likeKey, {});
    const likeMap = this.objectToMap<string[]>(likeObj);
    const users = likeMap.get(artifactId) || [];
    const likeCountBaseObj = await this.getJsonValue<Record<string, number>>(this.likeCountBaseKey, {});
    const likeCountBaseMap = this.objectToMap<number>(likeCountBaseObj);
    const nextBase = Math.max(totalCount - users.length, 0);
    likeCountBaseMap.set(artifactId, nextBase);
    await this.setJsonValue(this.likeCountBaseKey, this.mapToObject(likeCountBaseMap));
  }

  async savePublicFavorites(username: string, items: FavoriteItem[]): Promise<void> {
    if (!username) {
      return;
    }
    const cacheObj = await this.getJsonValue<Record<string, FavoriteItem[]>>(this.publicFavoriteCacheKey, {});
    const cacheMap = this.objectToMap<FavoriteItem[]>(cacheObj);
    const snapshot: FavoriteItem[] = items.map((item: FavoriteItem): FavoriteItem => {
      return this.cloneFavoriteItem(item);
    });
    const keys = this.getPublicCacheKeys(username);
    keys.forEach((key: string) => {
      cacheMap.set(key, snapshot);
    });
    await this.setJsonValue(this.publicFavoriteCacheKey, this.mapToObject(cacheMap));
  }

  async getPublicFavorites(username: string): Promise<FavoriteItem[]> {
    return this.getPublicFavoritesByAliases([username]);
  }

  async getPublicFavoritesByAliases(aliases: string[]): Promise<FavoriteItem[]> {
    return this.getPublicCachedItems<FavoriteItem>(this.publicFavoriteCacheKey, aliases);
  }

  async savePublicLikes(username: string, items: LikeItem[]): Promise<void> {
    if (!username) {
      return;
    }
    const cacheObj = await this.getJsonValue<Record<string, LikeItem[]>>(this.publicLikeCacheKey, {});
    const cacheMap = this.objectToMap<LikeItem[]>(cacheObj);
    const snapshot: LikeItem[] = items.map((item: LikeItem): LikeItem => {
      return {
        artifactId: item.artifactId,
        title: item.title,
        imageUrl: item.imageUrl,
        period: item.period,
        museum: item.museum,
        likedAt: item.likedAt
      };
    });
    const keys = this.getPublicCacheKeys(username);
    keys.forEach((key: string) => {
      cacheMap.set(key, snapshot);
    });
    await this.setJsonValue(this.publicLikeCacheKey, this.mapToObject(cacheMap));
  }

  async getPublicLikes(username: string): Promise<LikeItem[]> {
    return this.getPublicLikesByAliases([username]);
  }

  async getPublicLikesByAliases(aliases: string[]): Promise<LikeItem[]> {
    return this.getPublicCachedItems<LikeItem>(this.publicLikeCacheKey, aliases);
  }

  async savePublicComments(username: string, items: CommentItem[]): Promise<void> {
    if (!username) {
      return;
    }
    const cacheObj = await this.getJsonValue<Record<string, CommentItem[]>>(this.publicCommentCacheKey, {});
    const cacheMap = this.objectToMap<CommentItem[]>(cacheObj);
    const publicItems = items.filter((item: CommentItem) => item.status === ReviewStatus.Approved);
    const snapshot: CommentItem[] = publicItems.map((item: CommentItem): CommentItem => {
      return this.cloneCommentItem(item);
    });
    const keys = this.getPublicCacheKeys(username);
    keys.forEach((key: string) => {
      cacheMap.set(key, snapshot);
    });
    await this.setJsonValue(this.publicCommentCacheKey, this.mapToObject(cacheMap));
  }

  async getPublicComments(username: string): Promise<CommentItem[]> {
    return this.getPublicCommentsByAliases([username]);
  }

  async getPublicCommentsByAliases(aliases: string[]): Promise<CommentItem[]> {
    return this.getPublicCachedItems<CommentItem>(this.publicCommentCacheKey, aliases);
  }

  async savePublicUploads(username: string, items: UploadedPhotoItem[]): Promise<void> {
    if (!username) {
      return;
    }
    const cacheObj = await this.getJsonValue<Record<string, UploadedPhotoItem[]>>(this.publicUploadCacheKey, {});
    const cacheMap = this.objectToMap<UploadedPhotoItem[]>(cacheObj);
    const publicItems = items.filter((item: UploadedPhotoItem) => item.status === ReviewStatus.Approved);
    const snapshot: UploadedPhotoItem[] = publicItems.map((item: UploadedPhotoItem): UploadedPhotoItem => {
      return this.cloneUploadItem(item);
    });
    const keys = this.getPublicCacheKeys(username);
    keys.forEach((key: string) => {
      cacheMap.set(key, snapshot);
    });
    await this.setJsonValue(this.publicUploadCacheKey, this.mapToObject(cacheMap));
  }

  async getPublicUploads(username: string): Promise<UploadedPhotoItem[]> {
    return this.getPublicUploadsByAliases([username]);
  }

  async getPublicUploadsByAliases(aliases: string[]): Promise<UploadedPhotoItem[]> {
    return this.getPublicCachedItems<UploadedPhotoItem>(this.publicUploadCacheKey, aliases);
  }

  async hasLikeRecord(artifactId: string): Promise<boolean> {
    const likeObj = await this.getJsonValue<Record<string, string[]>>(this.likeKey, {});
    const likeMap = this.objectToMap<string[]>(likeObj);
    return likeMap.has(artifactId);
  }

  // 修改后的 toggleLike，支持 artifact 参数
  async toggleLike(artifactId: string, username: string, artifact?: Artifact): Promise<InteractionSummary> {
    // 1. 更新旧存储（文物→用户列表）
    const likeObj = await this.getJsonValue<Record<string, string[]>>(this.likeKey, {});
    const likeMap = this.objectToMap<string[]>(likeObj);
    const users = likeMap.get(artifactId) || [];
    const existingIndex = users.indexOf(username);
    if (existingIndex > -1) {
      users.splice(existingIndex, 1);
    } else {
      users.unshift(username);
    }
    likeMap.set(artifactId, users);
    await this.setJsonValue(this.likeKey, this.mapToObject(likeMap));

    // 2. 更新新存储（用户→LikeItem[]），如果提供了 artifact 则同步快照
    if (artifact) {
      const likeItemsObj = await this.getJsonValue<Record<string, LikeItem[]>>(this.likeItemsKey, {});
      const likeItemsMap = this.objectToMap<LikeItem[]>(likeItemsObj);
      let userItems = likeItemsMap.get(username) || [];
      if (existingIndex > -1) {
        // 取消点赞，移除该文物快照
        userItems = userItems.filter(item => item.artifactId !== artifactId);
      } else {
        // 点赞，插入快照
        const newItem = this.buildLikeItem(artifact);
        userItems = [newItem, ...userItems];
      }
      likeItemsMap.set(username, userItems);
      await this.setJsonValue(this.likeItemsKey, this.mapToObject(likeItemsMap));
    }

    await this.syncPublicLikesCache(username);
    await this.syncProfileStats(username);
    return this.getLikeSummary(artifactId, username);
  }

  async syncLikeState(
    artifactId: string,
    username: string,
    active: boolean,
    artifact?: Artifact
  ): Promise<InteractionSummary> {
    const current = await this.getLikeSummary(artifactId, username);
    if (current.active === active) {
      return current;
    }
    if (active) {
      return this.toggleLike(artifactId, username, artifact);
    }
    await this.removeLike(artifactId, username);
    return this.getLikeSummary(artifactId, username);
  }

  // 新增：获取用户点赞文物列表
  async getLikes(username: string): Promise<LikeItem[]> {
    if (!username) {
      return [];
    }
    const likeItemsObj = await this.getJsonValue<Record<string, LikeItem[]>>(this.likeItemsKey, {});
    const likeItemsMap = this.objectToMap<LikeItem[]>(likeItemsObj);
    return likeItemsMap.get(username) || [];
  }

  // 新增：取消点赞（无需 artifact 对象）
  async removeLike(artifactId: string, username: string): Promise<void> {
    // 1. 更新旧存储（文物→用户列表）
    const likeObj = await this.getJsonValue<Record<string, string[]>>(this.likeKey, {});
    const likeMap = this.objectToMap<string[]>(likeObj);
    const users = likeMap.get(artifactId) || [];
    const idx = users.indexOf(username);
    if (idx > -1) {
      users.splice(idx, 1);
      likeMap.set(artifactId, users);
      await this.setJsonValue(this.likeKey, this.mapToObject(likeMap));
    }

    // 2. 从用户点赞快照中移除
    const likeItemsObj = await this.getJsonValue<Record<string, LikeItem[]>>(this.likeItemsKey, {});
    const likeItemsMap = this.objectToMap<LikeItem[]>(likeItemsObj);
    let userItems = likeItemsMap.get(username) || [];
    userItems = userItems.filter((item: LikeItem) => item.artifactId !== artifactId);
    likeItemsMap.set(username, userItems);
    await this.setJsonValue(this.likeItemsKey, this.mapToObject(likeItemsMap));
    await this.syncPublicLikesCache(username);

    // 3. 更新统计数据
    await this.syncProfileStats(username);
  }

  async getFavoriteSummary(artifactId: string, username: string = ''): Promise<InteractionSummary> {
    const favoriteObj = await this.getJsonValue<Record<string, FavoriteItem[]>>(this.favoriteKey, {});
    const favoriteMap = this.objectToMap<FavoriteItem[]>(favoriteObj);
    const isActive = username
      ? (favoriteMap.get(username) || []).some((item: FavoriteItem) => item.artifactId === artifactId)
      : false;
    let favoriteUsers = 0;
    favoriteMap.forEach((list: FavoriteItem[]) => {
      if (list.some((item: FavoriteItem) => item.artifactId === artifactId)) {
        favoriteUsers += 1;
      }
    });
    return {
      active: isActive,
      count: this.buildFavoriteBaseCount(artifactId) + favoriteUsers
    };
  }

  async syncFavoriteState(
    artifact: Artifact,
    username: string,
    active: boolean,
    groupName: string = FAVORITE_GROUPS[0]
  ): Promise<InteractionSummary> {
    const current = await this.getFavoriteSummary(artifact.id, username);
    if (current.active === active) {
      if (active) {
        await this.moveFavoriteToGroup(artifact.id, username, groupName);
      }
      return this.getFavoriteSummary(artifact.id, username);
    }
    if (active) {
      await this.markFavoriteRemoved(username, artifact.id, false);
      return this.toggleFavorite(artifact, username, groupName);
    }
    await this.removeFavorite(artifact.id, username);
    return this.getFavoriteSummary(artifact.id, username);
  }

  async toggleFavorite(
    artifact: Artifact,
    username: string,
    groupName: string = FAVORITE_GROUPS[0]
  ): Promise<InteractionSummary> {
    const favoriteObj = await this.getJsonValue<Record<string, FavoriteItem[]>>(this.favoriteKey, {});
    const favoriteMap = this.objectToMap<FavoriteItem[]>(favoriteObj);
    const list = favoriteMap.get(username) || [];
    const existingIndex = list.findIndex((item: FavoriteItem) => item.artifactId === artifact.id);
    if (existingIndex > -1) {
      list.splice(existingIndex, 1);
      await this.markFavoriteRemoved(username, artifact.id, true);
    } else {
      const normalizedGroup = await this.normalizeFavoriteGroupForUser(username, groupName);
      list.unshift(this.buildFavoriteItem(artifact, normalizedGroup));
      await this.markFavoriteRemoved(username, artifact.id, false);
    }
    favoriteMap.set(username, list);
    await this.setJsonValue(this.favoriteKey, this.mapToObject(favoriteMap));
    await this.syncPublicFavoritesCache(username);
    await this.syncProfileStats(username);
    return this.getFavoriteSummary(artifact.id, username);
  }

  async getFavorites(username: string): Promise<FavoriteItem[]> {
    const favoriteObj = await this.getJsonValue<Record<string, FavoriteItem[]>>(this.favoriteKey, {});
    const favoriteMap = this.objectToMap<FavoriteItem[]>(favoriteObj);
    const favorites = favoriteMap.get(username) || [];
    const groups = await this.loadFavoriteGroups(username);
    const fallbackGroup = groups.length > 0 ? groups[0] : this.getDefaultFavoriteGroup();
    return favorites.map((item: FavoriteItem): FavoriteItem => {
      const normalizedItem: FavoriteItem = {
        artifactId: item.artifactId,
        title: item.title,
        imageUrl: item.imageUrl,
        period: item.period,
        museum: item.museum,
        groupName: groups.indexOf(item.groupName) > -1 ? item.groupName : fallbackGroup,
        createdAt: item.createdAt
      };
      return normalizedItem;
    });
  }

  async ensureFavoriteItem(username: string, item: FavoriteItem): Promise<void> {
    if (!username) {
      return;
    }
    const favoriteObj = await this.getJsonValue<Record<string, FavoriteItem[]>>(this.favoriteKey, {});
    const favoriteMap = this.objectToMap<FavoriteItem[]>(favoriteObj);
    const favorites = favoriteMap.get(username) || [];
    const existingIndex = favorites.findIndex((current: FavoriteItem) => current.artifactId === item.artifactId);
    const normalizedGroup = await this.normalizeFavoriteGroupForUser(username, item.groupName);
    const nextItem: FavoriteItem = {
      artifactId: item.artifactId,
      title: item.title,
      imageUrl: item.imageUrl,
      period: item.period,
      museum: item.museum,
      groupName: normalizedGroup,
      createdAt: item.createdAt
    };
    if (existingIndex > -1) {
      favorites[existingIndex] = nextItem;
    } else {
      favorites.unshift(this.cloneFavoriteItem(nextItem));
    }
    favoriteMap.set(username, favorites);
    await this.setJsonValue(this.favoriteKey, this.mapToObject(favoriteMap));
    await this.markFavoriteRemoved(username, item.artifactId, false);
    await this.syncPublicFavoritesCache(username);
  }

  async getRemovedFavoriteIds(username: string): Promise<string[]> {
    if (!username) {
      return [];
    }
    const removedMap = await this.getFavoriteRemovedMap();
    return removedMap.get(username) || [];
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
    const nextGroups = (await this.loadFavoriteGroups(username)).filter((item: string) => item !== groupName);
    const fallbackGroup = nextGroups.length > 0 ? nextGroups[0] : this.getDefaultFavoriteGroup();
    const groupObj = await this.getJsonValue<Record<string, string[]>>(this.favoriteGroupKey, {});
    const groupMap = this.objectToMap<string[]>(groupObj);
    const customGroups = nextGroups.filter((item: string) => FAVORITE_GROUPS.indexOf(item) === -1);
    groupMap.set(username, customGroups);
    await this.setJsonValue(this.favoriteGroupKey, this.mapToObject(groupMap));

    const favoriteObj = await this.getJsonValue<Record<string, FavoriteItem[]>>(this.favoriteKey, {});
    const favoriteMap = this.objectToMap<FavoriteItem[]>(favoriteObj);
    const favorites = (favoriteMap.get(username) || []).map((item: FavoriteItem): FavoriteItem => {
      const nextItem: FavoriteItem = {
        artifactId: item.artifactId,
        title: item.title,
        imageUrl: item.imageUrl,
        period: item.period,
        museum: item.museum,
        groupName: item.groupName === groupName ? fallbackGroup : item.groupName,
        createdAt: item.createdAt
      };
      return nextItem;
    });
    favoriteMap.set(username, favorites);
    await this.setJsonValue(this.favoriteKey, this.mapToObject(favoriteMap));
    await this.syncPublicFavoritesCache(username);
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
      const summary: FavoriteGroupSummary = {
        name: groupName,
        count: favorites.filter((item: FavoriteItem) => item.groupName === groupName).length,
        isDefault: FAVORITE_GROUPS.indexOf(groupName) > -1
      };
      return summary;
    });
  }

  async moveFavoriteToGroup(artifactId: string, username: string, groupName: string): Promise<string> {
    const favoriteObj = await this.getJsonValue<Record<string, FavoriteItem[]>>(this.favoriteKey, {});
    const favoriteMap = this.objectToMap<FavoriteItem[]>(favoriteObj);
    const favorites = favoriteMap.get(username) || [];
    const target = favorites.find((item: FavoriteItem) => item.artifactId === artifactId);
    if (!target) {
      const groups = await this.loadFavoriteGroups(username);
      return groups.length > 0 ? groups[0] : this.getDefaultFavoriteGroup();
    }
    target.groupName = await this.normalizeFavoriteGroupForUser(username, groupName);
    favoriteMap.set(username, favorites);
    await this.setJsonValue(this.favoriteKey, this.mapToObject(favoriteMap));
    await this.markFavoriteRemoved(username, artifactId, false);
    await this.syncPublicFavoritesCache(username);
    return target.groupName;
  }

  async cycleFavoriteGroup(artifactId: string, username: string): Promise<string> {
    const groups = await this.loadFavoriteGroups(username);
    const currentGroup = await this.getFavoriteGroupForArtifact(username, artifactId);
    const currentIndex = groups.indexOf(currentGroup);
    const nextIndex = currentIndex > -1 ? (currentIndex + 1) % groups.length : 0;
    return this.moveFavoriteToGroup(artifactId, username, groups[nextIndex]);
  }

  async removeFavorite(artifactId: string, username: string): Promise<void> {
    const favoriteObj = await this.getJsonValue<Record<string, FavoriteItem[]>>(this.favoriteKey, {});
    const favoriteMap = this.objectToMap<FavoriteItem[]>(favoriteObj);
    favoriteMap.set(username, (favoriteMap.get(username) || []).filter((item: FavoriteItem) => item.artifactId !== artifactId));
    await this.setJsonValue(this.favoriteKey, this.mapToObject(favoriteMap));
    await this.markFavoriteRemoved(username, artifactId, true);
    await this.syncPublicFavoritesCache(username);
    await this.syncProfileStats(username);
  }

  async recordHistory(artifact: Artifact, username: string): Promise<void> {
    if (!username) {
      return;
    }
    const historyObj = await this.getJsonValue<Record<string, HistoryItem[]>>(this.historyKey, {});
    const historyMap = this.objectToMap<HistoryItem[]>(historyObj);
    const currentHistory = historyMap.get(username) || [];
    const filtered = currentHistory.filter((item: HistoryItem) => item.artifactId !== artifact.id);
    filtered.unshift(this.buildHistoryItem(artifact));
    historyMap.set(username, filtered.slice(0, MAX_HISTORY));
    await this.setJsonValue(this.historyKey, this.mapToObject(historyMap));
  }

  async getHistory(username: string): Promise<HistoryItem[]> {
    const historyObj = await this.getJsonValue<Record<string, HistoryItem[]>>(this.historyKey, {});
    const historyMap = this.objectToMap<HistoryItem[]>(historyObj);
    return historyMap.get(username) || [];
  }

  async getCommentsForArtifact(artifactId: string, username: string = ''): Promise<CommentItem[]> {
    const comments = await this.syncCommentReviewStatus(
      await this.getJsonValue<CommentItem[]>(this.commentKey, [])
    );
    const current = comments.filter((item: CommentItem) => item.artifactId === artifactId);
    const approved = current.filter((item: CommentItem) => item.status === ReviewStatus.Approved);
    const ownPending = username
      ? current.filter((item: CommentItem) => item.username === username && item.status !== ReviewStatus.Approved)
      : [];
    const merged = this.sortByDateDesc<CommentItem>([
      ...this.getSeedComments(artifactId),
      ...approved,
      ...ownPending
    ]);
    return this.enrichComments(merged, username);
  }

  async getCommentLikeSummary(commentId: string, username: string = ''): Promise<InteractionSummary> {
    const likeMap = await this.getCommentLikeMap();
    const users = likeMap.get(commentId) || [];
    return {
      active: username ? users.indexOf(username) > -1 : false,
      count: this.buildCommentBaseCount(commentId) + users.length
    };
  }

  async toggleCommentLike(commentId: string, username: string): Promise<InteractionSummary> {
    const likeMap = await this.getCommentLikeMap();
    const users = likeMap.get(commentId) || [];
    const existingIndex = users.indexOf(username);
    if (existingIndex === -1) {
      users.unshift(username);
    } else {
      users.splice(existingIndex, 1);
    }
    likeMap.set(commentId, users);
    await this.setJsonValue(this.commentLikeKey, this.mapToObject(likeMap));
    await this.syncProfileStats(username);
    return this.getCommentLikeSummary(commentId, username);
  }

  async syncCommentLikeState(commentId: string, username: string, active: boolean): Promise<InteractionSummary> {
    const likeMap = await this.getCommentLikeMap();
    const users = likeMap.get(commentId) || [];
    const existingIndex = users.indexOf(username);
    if (active && existingIndex === -1) {
      users.unshift(username);
    }
    if (!active && existingIndex > -1) {
      users.splice(existingIndex, 1);
    }
    likeMap.set(commentId, users);
    await this.setJsonValue(this.commentLikeKey, this.mapToObject(likeMap));
    await this.syncProfileStats(username);
    return this.getCommentLikeSummary(commentId, username);
  }

  async addCommentMirror(
    artifact: Artifact,
    username: string,
    content: string,
    parentId: string = '',
    replyTo: string = ''
  ): Promise<CommentItem> {
    const record: CommentItem = {
      id: `comment-${Date.now()}`,
      artifactId: artifact.id,
      artifactTitle: artifact.title,
      username: username,
      content: content.trim(),
      createdAt: new Date().toISOString(),
      status: ReviewStatus.Pending
    };
    if (parentId) {
      record.parentId = parentId;
    }
    if (replyTo) {
      record.replyTo = replyTo;
    }
    await this.saveCommentRecord(record, username);
    await this.syncPublicCommentsCache(username);
    return record;
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

    await this.addCommentMirror(artifact, username, trimmed, parentId, replyTo);
    return { ok: true, message: '评论已提交，等待审核' };
  }

  async getUserComments(username: string): Promise<CommentItem[]> {
    const comments = await this.syncCommentReviewStatus(
      await this.getJsonValue<CommentItem[]>(this.commentKey, [])
    );
    const current = this.sortByDateDesc<CommentItem>(
      comments.filter((item: CommentItem) => item.username === username)
    );
    return this.enrichComments(current, username);
  }

  async addUpload(draft: UploadDraft): Promise<void> {
    const uploads = await this.getJsonValue<UploadedPhotoItem[]>(this.uploadKey, []);
    uploads.unshift({
      id: `upload-${Date.now()}`,
      artifactId: draft.artifactId,
      artifactTitle: draft.artifactTitle,
      username: draft.username,
      imageUri: draft.imageUri,
      location: draft.location.trim(),
      description: draft.description.trim(),
      createdAt: new Date().toISOString(),
      status: ReviewStatus.Pending
    });
    await this.setJsonValue(this.uploadKey, uploads);
    await this.syncPublicUploadsCache(draft.username);
    await this.syncProfileStats(draft.username);
  }

  async getUploads(username: string): Promise<UploadedPhotoItem[]> {
    const uploads = await this.syncUploadReviewStatus(
      await this.getJsonValue<UploadedPhotoItem[]>(this.uploadKey, [])
    );
    return uploads.filter((item: UploadedPhotoItem) => item.username === username);
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
      throw new Error('[InteractionStore] savePrivacy 失败：username 为空');
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
    console.info(`[InteractionStore] 保存隐私设置成功 username=${username}, privacy=${JSON.stringify(privacy)}`);
  }

  async getStats(username: string): Promise<UserInteractionStats> {
    const favorites = await this.getFavorites(username);
    const uploads = await this.getUploads(username);
    const comments = await this.getUserComments(username);
    const history = await this.getHistory(username);
    const likeObj = await this.getJsonValue<Record<string, string[]>>(this.likeKey, {});
    const likeMap = this.objectToMap<string[]>(likeObj);
    const commentLikeMap = await this.getCommentLikeMap();

    let likes = 0;
    likeMap.forEach((users: string[]) => {
      if (users.indexOf(username) > -1) {
        likes += 1;
      }
    });
    commentLikeMap.forEach((users: string[]) => {
      if (users.indexOf(username) > -1) {
        likes += 1;
      }
    });

    return {
      likes: likes,
      favorites: favorites.length,
      comments: comments.length,
      photos: uploads.length,
      history: history.length
    };
  }
}

export const interactionStore = new InteractionStore();

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
import { InteractionApiService } from '../services/InteractionApiService';
import { preferencesUtil } from '../utils/PreferencesUtil';

interface CommentResult {
  ok: boolean;
  message: string;
}

interface MapEntry<V> {
  key: string;
  value: V;
}

const BLOCKED_WORDS: string[] = ['广告', 'spam', '辱骂', '违法'];
const MAX_HISTORY = 20;
const COMMENT_REVIEW_DELAY_MS = 1500;

class InteractionStore {
  private readonly likeKey = 'pm.likes';
  private readonly likeItemsKey = 'pm.likeItems';
  private readonly favoriteKey = 'pm.favorites';
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

  private mapToEntries<K, V>(map: Map<K, V>): MapEntry<V>[] {
    const entries: MapEntry<V>[] = [];
    map.forEach((value, key) => {
      const entry: MapEntry<V> = {
        key: String(key),
        value: value
      };
      entries.push(entry);
    });
    return entries;
  }

  private entriesToMap<V>(entries: MapEntry<V>[]): Map<string, V> {
    const map = new Map<string, V>();
    if (!Array.isArray(entries)) {
      return map;
    }
    entries.forEach((entry: MapEntry<V>) => {
      map.set(entry.key, entry.value);
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
    const groupEntries = await this.getJsonValue<MapEntry<string[]>[]>(this.favoriteGroupKey, []);
    const groupMap = this.entriesToMap<string[]>(groupEntries);
    const customGroups = username ? (groupMap.get(username) || []) : [];
    return this.uniqueStrings([...FAVORITE_GROUPS, ...customGroups]);
  }

  private async saveFavoriteGroupsToLocal(username: string, groups: string[]): Promise<string[]> {
    const displayGroups = this.uniqueStrings(groups);
    const groupEntries = await this.getJsonValue<MapEntry<string[]>[]>(this.favoriteGroupKey, []);
    const groupMap = this.entriesToMap<string[]>(groupEntries);
    const customGroups = displayGroups.filter((item: string) => FAVORITE_GROUPS.indexOf(item) === -1);
    groupMap.set(username, customGroups);
    await this.setJsonValue(this.favoriteGroupKey, this.mapToEntries(groupMap));
    return this.uniqueStrings([...FAVORITE_GROUPS, ...customGroups]);
  }

  private async getLocalLikeItems(username: string): Promise<LikeItem[]> {
    if (!username) {
      return [];
    }
    const likeItemEntries = await this.getJsonValue<MapEntry<LikeItem[]>[]>(this.likeItemsKey, []);
    const likeItemsMap = this.entriesToMap<LikeItem[]>(likeItemEntries);
    return likeItemsMap.get(username) || [];
  }

  private async saveLocalLikeItems(username: string, items: LikeItem[]): Promise<void> {
    const likeItemEntries = await this.getJsonValue<MapEntry<LikeItem[]>[]>(this.likeItemsKey, []);
    const likeItemsMap = this.entriesToMap<LikeItem[]>(likeItemEntries);
    likeItemsMap.set(username, items);
    await this.setJsonValue(this.likeItemsKey, this.mapToEntries(likeItemsMap));
  }

  private async getLocalFavoriteItems(username: string): Promise<FavoriteItem[]> {
    const favoriteEntries = await this.getJsonValue<MapEntry<FavoriteItem[]>[]>(this.favoriteKey, []);
    const favoriteMap = this.entriesToMap<FavoriteItem[]>(favoriteEntries);
    return favoriteMap.get(username) || [];
  }

  private async saveLocalFavoriteItems(username: string, items: FavoriteItem[]): Promise<void> {
    const favoriteEntries = await this.getJsonValue<MapEntry<FavoriteItem[]>[]>(this.favoriteKey, []);
    const favoriteMap = this.entriesToMap<FavoriteItem[]>(favoriteEntries);
    favoriteMap.set(username, items);
    await this.setJsonValue(this.favoriteKey, this.mapToEntries(favoriteMap));
  }

  private async getLocalHistoryItems(username: string): Promise<HistoryItem[]> {
    const historyEntries = await this.getJsonValue<MapEntry<HistoryItem[]>[]>(this.historyKey, []);
    const historyMap = this.entriesToMap<HistoryItem[]>(historyEntries);
    return historyMap.get(username) || [];
  }

  private async saveLocalHistoryItems(username: string, items: HistoryItem[]): Promise<void> {
    const historyEntries = await this.getJsonValue<MapEntry<HistoryItem[]>[]>(this.historyKey, []);
    const historyMap = this.entriesToMap<HistoryItem[]>(historyEntries);
    historyMap.set(username, items);
    await this.setJsonValue(this.historyKey, this.mapToEntries(historyMap));
  }

  private async ensureLocalFavoriteGroup(username: string, groupName: string): Promise<void> {
    const groups = await this.loadFavoriteGroups(username);
    if (groups.indexOf(groupName) > -1) {
      return;
    }
    await this.saveFavoriteGroupsToLocal(username, [...groups, groupName]);
  }

  private async setLocalLikeState(
    artifactId: string,
    username: string,
    active: boolean,
    artifact?: Artifact
  ): Promise<void> {
    const likeEntries = await this.getJsonValue<MapEntry<string[]>[]>(this.likeKey, []);
    const likeMap = this.entriesToMap<string[]>(likeEntries);
    const users = likeMap.get(artifactId) || [];
    const existingIndex = users.indexOf(username);
    if (active && existingIndex === -1) {
      users.unshift(username);
    }
    if (!active && existingIndex > -1) {
      users.splice(existingIndex, 1);
    }
    likeMap.set(artifactId, users);
    await this.setJsonValue(this.likeKey, this.mapToEntries(likeMap));

    const currentItems = await this.getLocalLikeItems(username);
    let nextItems = currentItems.filter((item: LikeItem) => item.artifactId !== artifactId);
    if (active && artifact) {
      nextItems = [this.buildLikeItem(artifact), ...nextItems];
    }
    await this.saveLocalLikeItems(username, nextItems);
  }

  private async setLocalFavoriteState(
    artifact: Artifact,
    username: string,
    groupName: string,
    active: boolean
  ): Promise<void> {
    const currentItems = await this.getLocalFavoriteItems(username);
    let nextItems = currentItems.filter((item: FavoriteItem) => item.artifactId !== artifact.id);
    if (active) {
      await this.ensureLocalFavoriteGroup(username, groupName);
      const normalizedGroup = await this.normalizeFavoriteGroupForUser(username, groupName);
      nextItems = [this.buildFavoriteItem(artifact, normalizedGroup), ...nextItems];
    }
    await this.saveLocalFavoriteItems(username, nextItems);
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

  private mapRemoteReviewStatus(status?: string): ReviewStatus {
    const normalized = status ? status.toUpperCase() : '';
    if (normalized === 'APPROVED') {
      return ReviewStatus.Approved;
    }
    return ReviewStatus.Pending;
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
    const cloned: UploadedPhotoItem = {
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
    return cloned;
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
    const firstComment: CommentItem = {
      id: `seed-${artifactId}-1`,
      artifactId: artifactId,
      artifactTitle: '',
      username: '文博爱好者',
      content: '文物信息很完整，配合语音讲解一起看体验更好。',
      createdAt: '2026-05-10T10:00:00.000Z',
      status: ReviewStatus.Approved
    };
    const secondComment: CommentItem = {
      id: `seed-${artifactId}-2`,
      artifactId: artifactId,
      artifactTitle: '',
      username: '海外馆藏观察员',
      content: '如果能补充同年代关联文物，会更方便横向比较。',
      createdAt: '2026-05-12T14:30:00.000Z',
      status: ReviewStatus.Approved
    };
    return [firstComment, secondComment];
  }

  private buildFavoriteItem(artifact: Artifact, groupName: string): FavoriteItem {
    const item: FavoriteItem = {
      artifactId: artifact.id,
      title: artifact.title,
      imageUrl: artifact.imageUrl,
      period: artifact.period,
      museum: artifact.museum,
      groupName: groupName,
      createdAt: new Date().toISOString()
    };
    return item;
  }

  private buildHistoryItem(artifact: Artifact): HistoryItem {
    const item: HistoryItem = {
      artifactId: artifact.id,
      title: artifact.title,
      imageUrl: artifact.imageUrl,
      period: artifact.period,
      museum: artifact.museum,
      viewedAt: new Date().toISOString()
    };
    return item;
  }

  // 新增：构建 LikeItem 快照
  private buildLikeItem(artifact: Artifact): LikeItem {
    const item: LikeItem = {
      artifactId: artifact.id,
      title: artifact.title,
      imageUrl: artifact.imageUrl,
      period: artifact.period,
      museum: artifact.museum,
      likedAt: new Date().toISOString()
    };
    return item;
  }

  private async getCommentLikeMap(): Promise<Map<string, string[]>> {
    const commentLikeEntries = await this.getJsonValue<MapEntry<string[]>[]>(this.commentLikeKey, []);
    return this.entriesToMap<string[]>(commentLikeEntries);
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
    if (username) {
      try {
        const snapshots = await this.getLocalLikeItems(username);
        return await InteractionApiService.getArtifactLikeSummary(artifactId, username, snapshots);
      } catch (error) {
        console.error(`[InteractionStore] 远端获取点赞摘要失败，回退本地: ${JSON.stringify(error)}`);
      }
    }
    const likeEntries = await this.getJsonValue<MapEntry<string[]>[]>(this.likeKey, []);
    const likeMap = this.entriesToMap<string[]>(likeEntries);
    const users = likeMap.get(artifactId) || [];
    const summary: InteractionSummary = {
      active: username ? users.indexOf(username) > -1 : false,
      count: this.buildLikeBaseCount(artifactId) + users.length
    };
    return summary;
  }

  // 修改后的 toggleLike，支持 artifact 参数
  async toggleLike(artifactId: string, username: string, artifact?: Artifact): Promise<InteractionSummary> {
    if (username) {
      try {
        let summary = await this.getLikeSummary(artifactId, username);
        if (summary.active) {
          summary = await InteractionApiService.unlikeArtifact(artifactId);
        } else {
          summary = await InteractionApiService.likeArtifact(artifactId);
        }
        await this.setLocalLikeState(artifactId, username, summary.active, artifact);
        await this.syncProfileStats(username);
        return summary;
      } catch (error) {
        console.error(`[InteractionStore] 远端切换文物点赞失败，回退本地: ${JSON.stringify(error)}`);
      }
    }
    // 1. 更新旧存储（文物→用户列表）
    const likeEntries = await this.getJsonValue<MapEntry<string[]>[]>(this.likeKey, []);
    const likeMap = this.entriesToMap<string[]>(likeEntries);
    const users = likeMap.get(artifactId) || [];
    const existingIndex = users.indexOf(username);
    if (existingIndex > -1) {
      users.splice(existingIndex, 1);
    } else {
      users.unshift(username);
    }
    likeMap.set(artifactId, users);
    await this.setJsonValue(this.likeKey, this.mapToEntries(likeMap));

    // 2. 更新新存储（用户→LikeItem[]），如果提供了 artifact 则同步快照
    if (artifact) {
      const likeItemEntries = await this.getJsonValue<MapEntry<LikeItem[]>[]>(this.likeItemsKey, []);
      const likeItemsMap = this.entriesToMap<LikeItem[]>(likeItemEntries);
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
      await this.setJsonValue(this.likeItemsKey, this.mapToEntries(likeItemsMap));
    }

    await this.syncProfileStats(username);
    return this.getLikeSummary(artifactId, username);
  }

  // 新增：获取用户点赞文物列表
  async getLikes(username: string): Promise<LikeItem[]> {
    if (!username) {
      return [];
    }
    try {
      const snapshots = await this.getLocalLikeItems(username);
      const remoteItems = await InteractionApiService.getLikes(username, snapshots);
      await this.saveLocalLikeItems(username, remoteItems);
      return remoteItems;
    } catch (error) {
      console.error(`[InteractionStore] 远端获取点赞列表失败，回退本地: ${JSON.stringify(error)}`);
    }
    return this.getLocalLikeItems(username);
  }

  // 新增：取消点赞（无需 artifact 对象）
  async removeLike(artifactId: string, username: string): Promise<void> {
    if (username) {
      try {
        await InteractionApiService.unlikeArtifact(artifactId);
        await this.setLocalLikeState(artifactId, username, false);
        await this.syncProfileStats(username);
        return;
      } catch (error) {
        console.error(`[InteractionStore] 远端取消点赞失败，回退本地: ${JSON.stringify(error)}`);
      }
    }
    // 1. 更新旧存储（文物→用户列表）
    const likeEntries = await this.getJsonValue<MapEntry<string[]>[]>(this.likeKey, []);
    const likeMap = this.entriesToMap<string[]>(likeEntries);
    const users = likeMap.get(artifactId) || [];
    const idx = users.indexOf(username);
    if (idx > -1) {
      users.splice(idx, 1);
      likeMap.set(artifactId, users);
      await this.setJsonValue(this.likeKey, this.mapToEntries(likeMap));
    }

    // 2. 从用户点赞快照中移除
    const likeItemEntries = await this.getJsonValue<MapEntry<LikeItem[]>[]>(this.likeItemsKey, []);
    const likeItemsMap = this.entriesToMap<LikeItem[]>(likeItemEntries);
    let userItems = likeItemsMap.get(username) || [];
    userItems = userItems.filter(item => item.artifactId !== artifactId);
    likeItemsMap.set(username, userItems);
    await this.setJsonValue(this.likeItemsKey, this.mapToEntries(likeItemsMap));

    // 3. 更新统计数据
    await this.syncProfileStats(username);
  }

  async getFavoriteSummary(artifactId: string, username: string = ''): Promise<InteractionSummary> {
    if (username) {
      try {
        const snapshots = await this.getLocalFavoriteItems(username);
        return await InteractionApiService.getArtifactFavoriteSummary(artifactId, username, snapshots);
      } catch (error) {
        console.error(`[InteractionStore] 远端获取收藏摘要失败，回退本地: ${JSON.stringify(error)}`);
      }
    }
    const favoriteEntries = await this.getJsonValue<MapEntry<FavoriteItem[]>[]>(this.favoriteKey, []);
    const favoriteMap = this.entriesToMap<FavoriteItem[]>(favoriteEntries);
    const isActive = username
      ? (favoriteMap.get(username) || []).some((item: FavoriteItem) => item.artifactId === artifactId)
      : false;
    let favoriteUsers = 0;
    favoriteMap.forEach((list: FavoriteItem[]) => {
      if (list.some((item: FavoriteItem) => item.artifactId === artifactId)) {
        favoriteUsers += 1;
      }
    });
    const summary: InteractionSummary = {
      active: isActive,
      count: this.buildFavoriteBaseCount(artifactId) + favoriteUsers
    };
    return summary;
  }

  async toggleFavorite(
    artifact: Artifact,
    username: string,
    groupName: string = FAVORITE_GROUPS[0]
  ): Promise<InteractionSummary> {
    if (username) {
      try {
        const current = await this.getFavoriteSummary(artifact.id, username);
        let summary: InteractionSummary;
        if (current.active) {
          await InteractionApiService.removeFavorite(username, artifact.id);
          await this.setLocalFavoriteState(artifact, username, groupName, false);
          const inactiveSummary: InteractionSummary = {
            active: false,
            count: Math.max(0, current.count - 1)
          };
          summary = inactiveSummary;
        } else {
          await InteractionApiService.addFavorite(username, artifact.id, groupName);
          await this.setLocalFavoriteState(artifact, username, groupName, true);
          summary = await this.getFavoriteSummary(artifact.id, username);
        }
        await this.syncProfileStats(username);
        return summary;
      } catch (error) {
        console.error(`[InteractionStore] 远端切换收藏失败，回退本地: ${JSON.stringify(error)}`);
      }
    }
    const favoriteEntries = await this.getJsonValue<MapEntry<FavoriteItem[]>[]>(this.favoriteKey, []);
    const favoriteMap = this.entriesToMap<FavoriteItem[]>(favoriteEntries);
    const list = favoriteMap.get(username) || [];
    const existingIndex = list.findIndex((item: FavoriteItem) => item.artifactId === artifact.id);
    if (existingIndex > -1) {
      list.splice(existingIndex, 1);
    } else {
      const normalizedGroup = await this.normalizeFavoriteGroupForUser(username, groupName);
      list.unshift(this.buildFavoriteItem(artifact, normalizedGroup));
    }
    favoriteMap.set(username, list);
    await this.setJsonValue(this.favoriteKey, this.mapToEntries(favoriteMap));
    await this.syncProfileStats(username);
    return this.getFavoriteSummary(artifact.id, username);
  }

  async getFavorites(username: string): Promise<FavoriteItem[]> {
    const favorites = await this.getLocalFavoriteItems(username);
    const groups = await this.loadFavoriteGroups(username);
    const fallbackGroup = groups.length > 0 ? groups[0] : this.getDefaultFavoriteGroup();
    const normalizeLocalFavorites = (): FavoriteItem[] => favorites.map((item: FavoriteItem): FavoriteItem => {
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
    if (username) {
      try {
        const remoteFavorites = await InteractionApiService.getFavorites(username, normalizeLocalFavorites());
        await this.saveLocalFavoriteItems(username, remoteFavorites);
        await this.saveFavoriteGroupsToLocal(username, remoteFavorites.map((item: FavoriteItem) => item.groupName));
        return remoteFavorites;
      } catch (error) {
        console.error(`[InteractionStore] 远端获取收藏列表失败，回退本地: ${JSON.stringify(error)}`);
      }
    }
    return normalizeLocalFavorites();
  }

  async getFavoriteGroups(username: string): Promise<string[]> {
    if (username) {
      try {
        const remoteGroups = await InteractionApiService.getFavoriteGroups(username);
        return await this.saveFavoriteGroupsToLocal(username, remoteGroups);
      } catch (error) {
        console.error(`[InteractionStore] 远端获取收藏夹失败，回退本地: ${JSON.stringify(error)}`);
      }
    }
    return this.loadFavoriteGroups(username);
  }

  async addFavoriteGroup(username: string, groupName: string): Promise<string[]> {
    const trimmed = groupName.trim();
    if (!username || !trimmed) {
      return this.loadFavoriteGroups(username);
    }
    try {
      const remoteGroups = await InteractionApiService.addFavoriteGroup(username, trimmed);
      return await this.saveFavoriteGroupsToLocal(username, remoteGroups);
    } catch (error) {
      console.error(`[InteractionStore] 远端新建收藏夹失败，回退本地: ${JSON.stringify(error)}`);
    }
    const groupEntries = await this.getJsonValue<MapEntry<string[]>[]>(this.favoriteGroupKey, []);
    const groupMap = this.entriesToMap<string[]>(groupEntries);
    const currentGroups = groupMap.get(username) || [];
    groupMap.set(username, this.uniqueStrings([...currentGroups, trimmed]));
    await this.setJsonValue(this.favoriteGroupKey, this.mapToEntries(groupMap));
    return this.loadFavoriteGroups(username);
  }

  async deleteFavoriteGroup(username: string, groupName: string): Promise<string[]> {
    if (!username || FAVORITE_GROUPS.indexOf(groupName) > -1) {
      return this.loadFavoriteGroups(username);
    }
    try {
      const remoteGroups = await InteractionApiService.deleteFavoriteGroup(username, groupName);
      const currentFavorites = await this.getLocalFavoriteItems(username);
      await this.saveLocalFavoriteItems(
        username,
        currentFavorites.filter((item: FavoriteItem) => item.groupName !== groupName)
      );
      await this.syncProfileStats(username);
      return await this.saveFavoriteGroupsToLocal(username, remoteGroups);
    } catch (error) {
      console.error(`[InteractionStore] 远端删除收藏夹失败，回退本地: ${JSON.stringify(error)}`);
    }
    const nextGroups = (await this.loadFavoriteGroups(username)).filter((item: string) => item !== groupName);
    const groupEntries = await this.getJsonValue<MapEntry<string[]>[]>(this.favoriteGroupKey, []);
    const groupMap = this.entriesToMap<string[]>(groupEntries);
    const customGroups = nextGroups.filter((item: string) => FAVORITE_GROUPS.indexOf(item) === -1);
    groupMap.set(username, customGroups);
    await this.setJsonValue(this.favoriteGroupKey, this.mapToEntries(groupMap));

    const favoriteEntries = await this.getJsonValue<MapEntry<FavoriteItem[]>[]>(this.favoriteKey, []);
    const favoriteMap = this.entriesToMap<FavoriteItem[]>(favoriteEntries);
    const favorites = (favoriteMap.get(username) || []).filter((item: FavoriteItem) => item.groupName !== groupName);
    favoriteMap.set(username, favorites);
    await this.setJsonValue(this.favoriteKey, this.mapToEntries(favoriteMap));
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
    if (username) {
      try {
        const summaries = await InteractionApiService.getFavoriteGroupSummaries(username);
        await this.saveFavoriteGroupsToLocal(username, summaries.map((item: FavoriteGroupSummary) => item.name));
        return summaries;
      } catch (error) {
        console.error(`[InteractionStore] 远端获取收藏夹统计失败，回退本地: ${JSON.stringify(error)}`);
      }
    }
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
    if (username) {
      try {
        await InteractionApiService.moveFavorite(username, artifactId, groupName);
        const localFavorites = await this.getLocalFavoriteItems(username);
        const target = localFavorites.find((item: FavoriteItem) => item.artifactId === artifactId);
        if (target) {
          target.groupName = await this.normalizeFavoriteGroupForUser(username, groupName);
          await this.saveLocalFavoriteItems(username, localFavorites);
          await this.ensureLocalFavoriteGroup(username, target.groupName);
          return target.groupName;
        }
        await this.ensureLocalFavoriteGroup(username, groupName);
        return await this.normalizeFavoriteGroupForUser(username, groupName);
      } catch (error) {
        console.error(`[InteractionStore] 远端切换收藏分组失败，回退本地: ${JSON.stringify(error)}`);
      }
    }
    const favoriteEntries = await this.getJsonValue<MapEntry<FavoriteItem[]>[]>(this.favoriteKey, []);
    const favoriteMap = this.entriesToMap<FavoriteItem[]>(favoriteEntries);
    const favorites = favoriteMap.get(username) || [];
    const target = favorites.find((item: FavoriteItem) => item.artifactId === artifactId);
    if (!target) {
      const groups = await this.loadFavoriteGroups(username);
      return groups.length > 0 ? groups[0] : this.getDefaultFavoriteGroup();
    }
    target.groupName = await this.normalizeFavoriteGroupForUser(username, groupName);
    favoriteMap.set(username, favorites);
    await this.setJsonValue(this.favoriteKey, this.mapToEntries(favoriteMap));
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
    if (username) {
      try {
        await InteractionApiService.removeFavorite(username, artifactId);
        const localFavorites = await this.getLocalFavoriteItems(username);
        await this.saveLocalFavoriteItems(
          username,
          localFavorites.filter((item: FavoriteItem) => item.artifactId !== artifactId)
        );
        await this.syncProfileStats(username);
        return;
      } catch (error) {
        console.error(`[InteractionStore] 远端取消收藏失败，回退本地: ${JSON.stringify(error)}`);
      }
    }
    const favoriteEntries = await this.getJsonValue<MapEntry<FavoriteItem[]>[]>(this.favoriteKey, []);
    const favoriteMap = this.entriesToMap<FavoriteItem[]>(favoriteEntries);
    favoriteMap.set(username, (favoriteMap.get(username) || []).filter((item: FavoriteItem) => item.artifactId !== artifactId));
    await this.setJsonValue(this.favoriteKey, this.mapToEntries(favoriteMap));
    await this.syncProfileStats(username);
  }

  async recordHistory(artifact: Artifact, username: string): Promise<void> {
    if (!username) {
      return;
    }
    const currentHistory = await this.getLocalHistoryItems(username);
    const filtered = currentHistory.filter((item: HistoryItem) => item.artifactId !== artifact.id);
    filtered.unshift(this.buildHistoryItem(artifact));
    await this.saveLocalHistoryItems(username, filtered.slice(0, MAX_HISTORY));
    try {
      await InteractionApiService.recordHistory(username, artifact.id);
    } catch (error) {
      console.error(`[InteractionStore] 远端记录浏览历史失败，保留本地记录: ${JSON.stringify(error)}`);
    }
  }

  async getHistory(username: string): Promise<HistoryItem[]> {
    const localHistory = await this.getLocalHistoryItems(username);
    if (username) {
      try {
        const remoteHistory = await InteractionApiService.getHistory(username, localHistory);
        await this.saveLocalHistoryItems(username, remoteHistory);
        return remoteHistory;
      } catch (error) {
        console.error(`[InteractionStore] 远端获取浏览历史失败，回退本地: ${JSON.stringify(error)}`);
      }
    }
    return localHistory;
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
    try {
      const remoteComments = await InteractionApiService.getCommentsForArtifact(artifactId);
      const mergedRemote = this.sortByDateDesc<CommentItem>([
        ...remoteComments,
        ...ownPending.filter((item: CommentItem) => remoteComments.findIndex((remote: CommentItem) => remote.id === item.id) === -1)
      ]);
      return this.enrichComments(mergedRemote, username);
    } catch (error) {
      console.error(`[InteractionStore] 远端获取评论列表失败，回退本地: ${JSON.stringify(error)}`);
    }
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
    const summary: InteractionSummary = {
      active: username ? users.indexOf(username) > -1 : false,
      count: this.buildCommentBaseCount(commentId) + users.length
    };
    return summary;
  }

  async toggleCommentLike(commentId: string, username: string): Promise<InteractionSummary> {
    if (username) {
      try {
        const summary = await InteractionApiService.likeComment(commentId);
        const likeMap = await this.getCommentLikeMap();
        const users = likeMap.get(commentId) || [];
        if (users.indexOf(username) === -1) {
          users.unshift(username);
          likeMap.set(commentId, users);
          await this.setJsonValue(this.commentLikeKey, this.mapToEntries(likeMap));
        }
        await this.syncProfileStats(username);
        return summary;
      } catch (error) {
        console.error(`[InteractionStore] 远端评论点赞失败，回退本地: ${JSON.stringify(error)}`);
      }
    }
    const likeMap = await this.getCommentLikeMap();
    const users = likeMap.get(commentId) || [];
    const existingIndex = users.indexOf(username);
    if (existingIndex > -1) {
      users.splice(existingIndex, 1);
    } else {
      users.unshift(username);
    }
    likeMap.set(commentId, users);
    await this.setJsonValue(this.commentLikeKey, this.mapToEntries(likeMap));
    await this.syncProfileStats(username);
    return this.getCommentLikeSummary(commentId, username);
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
      const result: CommentResult = { ok: false, message: '评论内容不能为空' };
      return result;
    }
    if (trimmed.length < 2) {
      const result: CommentResult = { ok: false, message: '评论至少输入 2 个字' };
      return result;
    }
    if (trimmed.length > 200) {
      const result: CommentResult = { ok: false, message: '评论请控制在 200 字以内' };
      return result;
    }
    if (BLOCKED_WORDS.some((word: string) => trimmed.indexOf(word) > -1)) {
      const result: CommentResult = { ok: false, message: '评论包含敏感词，请修改后再试' };
      return result;
    }

    try {
      const remoteResult = await InteractionApiService.addComment(artifact.id, trimmed, parentId);
      const comments = await this.getJsonValue<CommentItem[]>(this.commentKey, []);
      const record: CommentItem = {
        id: remoteResult.objectId || `comment-${Date.now()}`,
        artifactId: artifact.id,
        artifactTitle: artifact.title,
        username: username,
        content: trimmed,
        createdAt: new Date().toISOString(),
        status: this.mapRemoteReviewStatus(remoteResult.status)
      };
      if (parentId) {
        record.parentId = parentId;
      }
      if (replyTo) {
        record.replyTo = replyTo;
      }
      comments.unshift(record);
      await this.setJsonValue(this.commentKey, comments);
      await this.syncProfileStats(username);
      const result: CommentResult = { ok: true, message: remoteResult.message || '评论已提交，等待审核' };
      return result;
    } catch (error) {
      console.error(`[InteractionStore] 远端发表评论失败，回退本地: ${JSON.stringify(error)}`);
    }

    const comments = await this.getJsonValue<CommentItem[]>(this.commentKey, []);
    const record: CommentItem = {
      id: `comment-${Date.now()}`,
      artifactId: artifact.id,
      artifactTitle: artifact.title,
      username: username,
      content: trimmed,
      createdAt: new Date().toISOString(),
      status: ReviewStatus.Pending
    };
    if (parentId) {
      record.parentId = parentId;
    }
    if (replyTo) {
      record.replyTo = replyTo;
    }
    comments.unshift(record);
    await this.setJsonValue(this.commentKey, comments);
    await this.syncProfileStats(username);
    const result: CommentResult = { ok: true, message: '评论已发布，约 1.5 秒后自动通过审核' };
    return result;
  }

  async getUserComments(username: string): Promise<CommentItem[]> {
    const comments = await this.syncCommentReviewStatus(
      await this.getJsonValue<CommentItem[]>(this.commentKey, [])
    );
    try {
      const remoteComments = await InteractionApiService.getUserComments(username);
      const localPending = comments.filter((item: CommentItem) => {
        return item.username === username && item.status !== ReviewStatus.Approved;
      });
      const mergedRemote = this.sortByDateDesc<CommentItem>([
        ...remoteComments,
        ...localPending.filter((item: CommentItem) => remoteComments.findIndex((remote: CommentItem) => remote.id === item.id) === -1)
      ]);
      return this.enrichComments(mergedRemote, username);
    } catch (error) {
      console.error(`[InteractionStore] 远端获取我的评论失败，回退本地: ${JSON.stringify(error)}`);
    }
    const current = this.sortByDateDesc<CommentItem>(
      comments.filter((item: CommentItem) => item.username === username)
    );
    return this.enrichComments(current, username);
  }

  async addUpload(draft: UploadDraft): Promise<void> {
    const uploads = await this.getJsonValue<UploadedPhotoItem[]>(this.uploadKey, []);
    const uploadItem: UploadedPhotoItem = {
      id: `upload-${Date.now()}`,
      artifactId: draft.artifactId,
      artifactTitle: draft.artifactTitle,
      username: draft.username,
      imageUri: draft.imageUri,
      location: draft.location.trim(),
      description: draft.description.trim(),
      createdAt: new Date().toISOString(),
      status: ReviewStatus.Pending
    };
    uploads.unshift(uploadItem);
    await this.setJsonValue(this.uploadKey, uploads);
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
      return DEFAULT_PRIVACY_SETTINGS;
    }

    try {
      const remotePrivacy = await InteractionApiService.getPrivacy(username);
      const privacyEntries = await this.getJsonValue<MapEntry<PrivacySettings>[]>(this.privacyKey, []);
      const privacyMap = this.entriesToMap<PrivacySettings>(privacyEntries);
      privacyMap.set(username, remotePrivacy);
      await this.setJsonValue(this.privacyKey, this.mapToEntries(privacyMap));
      return remotePrivacy;
    } catch (error) {
      console.error(`[InteractionStore] 远端获取隐私设置失败，回退本地: ${JSON.stringify(error)}`);
    }
    const privacyEntries = await this.getJsonValue<MapEntry<PrivacySettings>[]>(this.privacyKey, []);
    const privacyMap = this.entriesToMap<PrivacySettings>(privacyEntries);
    return privacyMap.get(username) || DEFAULT_PRIVACY_SETTINGS;
  }

  async savePrivacy(username: string, privacy: PrivacySettings): Promise<void> {
    if (!username) {
      throw new Error('[InteractionStore] savePrivacy 失败：username 为空');
    }

    try {
      const saved = await InteractionApiService.savePrivacy(username, privacy);
      const privacyEntries = await this.getJsonValue<MapEntry<PrivacySettings>[]>(this.privacyKey, []);
      const privacyMap = this.entriesToMap<PrivacySettings>(privacyEntries);
      privacyMap.set(username, saved);
      await this.setJsonValue(this.privacyKey, this.mapToEntries(privacyMap));
      console.info(`[InteractionStore] 远端保存隐私设置成功 username=${username}, privacy=${JSON.stringify(saved)}`);
      return;
    } catch (error) {
      console.error(`[InteractionStore] 远端保存隐私设置失败，回退本地: ${JSON.stringify(error)}`);
    }
    const privacyEntries = await this.getJsonValue<MapEntry<PrivacySettings>[]>(this.privacyKey, []);
    const privacyMap = this.entriesToMap<PrivacySettings>(privacyEntries);
    privacyMap.set(username, privacy);
    await this.setJsonValue(this.privacyKey, this.mapToEntries(privacyMap));
  }

  async getStats(username: string): Promise<UserInteractionStats> {
    const favorites = await this.getFavorites(username);
    const uploads = await this.getUploads(username);
    const comments = await this.getUserComments(username);
    const history = await this.getHistory(username);
    const likesList = await this.getLikes(username);
    const commentLikeMap = await this.getCommentLikeMap();

    let likes = likesList.length;
    commentLikeMap.forEach((users: string[]) => {
      if (users.indexOf(username) > -1) {
        likes += 1;
      }
    });

    const stats: UserInteractionStats = {
      likes: likes,
      favorites: favorites.length,
      comments: comments.length,
      photos: uploads.length,
      history: history.length
    };
    return stats;
  }
}

export const interactionStore = new InteractionStore();

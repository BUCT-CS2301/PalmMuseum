import common from '@ohos.app.ability.common';
import { HttpApi } from '../network/HttpApi';
import { MuseumArtifactApi } from '../network/MuseumArtifactApi';
import { Artifact } from '../models/Artifact';
import {
  CommentItem,
  FAVORITE_GROUPS,
  FavoriteGroupSummary,
  FavoriteItem,
  HistoryItem,
  InteractionSummary,
  LikeItem,
  ReviewStatus,
  UploadedPhotoItem,
  UploadDraft
} from '../models/InteractionModels';
import { interactionStore } from '../store/InteractionStore';

interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

export interface ActionResult {
  ok: boolean;
  message: string;
}

interface ToggleResponseData {
  likeCount?: number;
  favoriteCount?: number;
  isLiked?: boolean;
  isFavorited?: boolean;
}

interface BackendFavoriteRecord {
  artifactId?: string;
  objectId?: string;
  artifactTitle?: string;
  title?: string;
  imageUrl?: string;
  period?: string;
  museum?: string;
  groupName?: string;
  createTime?: string;
  createdAt?: string;
}

interface BackendLikeRecord {
  artifactId?: string;
  objectId?: string;
  artifactTitle?: string;
  title?: string;
  imageUrl?: string;
  period?: string;
  museum?: string;
  createTime?: string;
  likedAt?: string;
}

interface BackendHistoryRecord {
  artifactId?: string;
  objectId?: string;
  artifactTitle?: string;
  title?: string;
  imageUrl?: string;
  period?: string;
  museum?: string;
  createTime?: string;
  viewedAt?: string;
}

interface BackendCommentRecord {
  objectId?: string;
  commentId?: string;
  id?: string;
  artifactId?: string;
  objectRelicId?: string;
  artifactTitle?: string;
  title?: string;
  username?: string;
  userName?: string;
  nickname?: string;
  content?: string;
  createTime?: string;
  createdAt?: string;
  status?: string;
  auditStatus?: string;
  parentId?: string;
  parentCommentId?: string;
  replyTo?: string;
  replyToUser?: string;
  likeCount?: number;
  liked?: boolean;
  isLiked?: boolean;
  replies?: BackendCommentReplyRecord[];
}

interface BackendCommentReplyRecord {
  objectId?: string;
  commentId?: string;
  id?: string;
  userName?: string;
  username?: string;
  nickname?: string;
  content?: string;
  createTime?: string;
  createdAt?: string;
  likeCount?: number;
  liked?: boolean;
  isLiked?: boolean;
}

interface BackendUploadRecord {
  uploadId?: string;
  objectId?: string;
  id?: string;
  artifactId?: string;
  artifactTitle?: string;
  title?: string;
  username?: string;
  userName?: string;
  imageUrl?: string;
  photoUrl?: string;
  location?: string;
  description?: string;
  createTime?: string;
  createdAt?: string;
  status?: string;
  auditStatus?: string;
}

interface ArtifactMeta {
  title: string;
  imageUrl: string;
  period: string;
  museum: string;
}

interface CreatedAtEntity {
  createdAt: string;
}

interface IdentifiedCreatedAtEntity extends CreatedAtEntity {
  id: string;
}

interface RecordHistoryRequestBody {
  artifactId: string;
  objectId: string;
  artifactTitle: string;
  title: string;
}

interface EmptyRequestBody {
}

interface FavoriteRequestBody {
  artifactId: string;
  objectId: string;
  artifactTitle: string;
  title: string;
  groupName: string;
}

interface CommentRequestBody {
  artifactId: string;
  objectId: string;
  content: string;
  parentId: string;
  replyTo: string;
}

export interface CommentResult {
  ok: boolean;
  message: string;
}

export class InteractionService {
  private static readonly BLOCKED_WORDS: string[] = ['广告', 'spam', '辱骂', '违法'];

  private static getDefaultGroup(): string {
    return FAVORITE_GROUPS.length > 0 ? FAVORITE_GROUPS[0] : '默认收藏夹';
  }

  private static getStringValue(source: Object | null | undefined, keys: string[]): string {
    if (!source) {
      return '';
    }
    const record = source as Record<string, Object>;
    for (let index = 0; index < keys.length; index += 1) {
      const value = record[keys[index]];
      if (typeof value === 'string' && value.trim().length > 0) {
        return value.trim();
      }
      if (typeof value === 'number') {
        return `${value}`;
      }
    }
    return '';
  }

  private static getNumberValue(source: Object | null | undefined, keys: string[]): number {
    if (!source) {
      return 0;
    }
    const record = source as Record<string, Object>;
    for (let index = 0; index < keys.length; index += 1) {
      const value = record[keys[index]];
      if (typeof value === 'number') {
        return value;
      }
      if (typeof value === 'string') {
        const parsed = Number(value);
        if (!Number.isNaN(parsed)) {
          return parsed;
        }
      }
    }
    return 0;
  }

  private static getBooleanValue(source: Object | null | undefined, keys: string[]): boolean | undefined {
    if (!source) {
      return undefined;
    }
    const record = source as Record<string, Object>;
    for (let index = 0; index < keys.length; index += 1) {
      const value = record[keys[index]];
      if (typeof value === 'boolean') {
        return value;
      }
      if (typeof value === 'number') {
        return value > 0;
      }
      if (typeof value === 'string') {
        const text = value.toLowerCase();
        if (text === 'true' || text === '1') {
          return true;
        }
        if (text === 'false' || text === '0') {
          return false;
        }
      }
    }
    return undefined;
  }

  private static extractList<T>(data: Object | T[] | null | undefined, extraKeys: string[] = []): T[] {
    if (!data) {
      return [];
    }
    if (Array.isArray(data)) {
      return data as T[];
    }
    const record = data as Record<string, Object>;
    const keys = [...extraKeys, 'items', 'records', 'list', 'rows'];
    for (let index = 0; index < keys.length; index += 1) {
      const value = record[keys[index]];
      if (Array.isArray(value)) {
        return value as T[];
      }
    }
    return [];
  }

  private static normalizeTime(primary: string, secondary: string = ''): string {
    if (primary && primary.length > 0) {
      return primary;
    }
    if (secondary && secondary.length > 0) {
      return secondary;
    }
    return new Date().toISOString();
  }

  private static toReviewStatus(status: string): ReviewStatus {
    const value = status.toUpperCase();
    if (value.indexOf('APPROVED') > -1 || value.indexOf('PASS') > -1) {
      return ReviewStatus.Approved;
    }
    return ReviewStatus.Pending;
  }

  private static sortByCreatedAtDesc<T extends CreatedAtEntity>(items: T[]): T[] {
    return [...items].sort((left: T, right: T) => {
      const leftTime = new Date(left.createdAt).getTime();
      const rightTime = new Date(right.createdAt).getTime();
      return rightTime - leftTime;
    });
  }

  private static mergeById<T extends IdentifiedCreatedAtEntity>(primary: T[], secondary: T[]): T[] {
    const merged = new Map<string, T>();
    primary.forEach((item: T) => {
      merged.set(item.id, item);
    });
    secondary.forEach((item: T) => {
      if (!merged.has(item.id)) {
        merged.set(item.id, item);
      }
    });
    return InteractionService.sortByCreatedAtDesc(Array.from(merged.values()));
  }

  private static isSameComment(left: CommentItem, right: CommentItem): boolean {
    if (left.id === right.id) {
      return true;
    }
    if (left.artifactId !== right.artifactId || left.content !== right.content) {
      return false;
    }
    if ((left.parentId || '') !== (right.parentId || '') || (left.replyTo || '') !== (right.replyTo || '')) {
      return false;
    }
    const leftTime = new Date(left.createdAt).getTime();
    const rightTime = new Date(right.createdAt).getTime();
    if (Number.isNaN(leftTime) || Number.isNaN(rightTime)) {
      return true;
    }
    return Math.abs(leftTime - rightTime) <= 5 * 60 * 1000;
  }

  private static mergeComments(primary: CommentItem[], secondary: CommentItem[]): CommentItem[] {
    const merged: CommentItem[] = [...primary];
    secondary.forEach((item: CommentItem) => {
      const exists = merged.some((current: CommentItem) => InteractionService.isSameComment(current, item));
      if (!exists) {
        merged.push(item);
      }
    });
    return InteractionService.sortByCreatedAtDesc(merged);
  }

  private static async syncPublicCommentsFromArtifact(comments: CommentItem[]): Promise<void> {
    const userCommentMap = new Map<string, CommentItem[]>();
    for (let index = 0; index < comments.length; index += 1) {
      const item = comments[index];
      if (!item.username || item.status !== ReviewStatus.Approved) {
        continue;
      }
      const current = userCommentMap.get(item.username) || [];
      current.push(item);
      userCommentMap.set(item.username, current);
    }

    const usernames = Array.from(userCommentMap.keys());
    for (let index = 0; index < usernames.length; index += 1) {
      const username = usernames[index];
      const cached = await interactionStore.getPublicCommentsByAliases([username]);
      const current = userCommentMap.get(username) || [];
      const merged = InteractionService.mergeComments(cached, current);
      await interactionStore.savePublicComments(username, merged);
    }
  }

  private static buildMetaFromFavoriteItems(items: FavoriteItem[]): Map<string, ArtifactMeta> {
    const metaMap = new Map<string, ArtifactMeta>();
    items.forEach((item: FavoriteItem) => {
      metaMap.set(item.artifactId, {
        title: item.title,
        imageUrl: item.imageUrl,
        period: item.period,
        museum: item.museum
      });
    });
    return metaMap;
  }

  private static buildMetaFromLikeItems(items: LikeItem[]): Map<string, ArtifactMeta> {
    const metaMap = new Map<string, ArtifactMeta>();
    items.forEach((item: LikeItem) => {
      metaMap.set(item.artifactId, {
        title: item.title,
        imageUrl: item.imageUrl,
        period: item.period,
        museum: item.museum
      });
    });
    return metaMap;
  }

  private static buildMetaFromHistoryItems(items: HistoryItem[]): Map<string, ArtifactMeta> {
    const metaMap = new Map<string, ArtifactMeta>();
    items.forEach((item: HistoryItem) => {
      metaMap.set(item.artifactId, {
        title: item.title,
        imageUrl: item.imageUrl,
        period: item.period,
        museum: item.museum
      });
    });
    return metaMap;
  }

  private static async resolveArtifactMeta(
    artifactId: string,
    metaMap: Map<string, ArtifactMeta>,
    fallbackTitle: string = ''
  ): Promise<ArtifactMeta> {
    const cached = metaMap.get(artifactId);
    if (cached && (cached.title || cached.imageUrl || cached.period || cached.museum)) {
      return cached;
    }

    try {
      const detail: Artifact = await MuseumArtifactApi.getArtifactDetail(artifactId);
      const meta: ArtifactMeta = {
        title: detail.title,
        imageUrl: detail.imageUrl,
        period: detail.period,
        museum: detail.museum
      };
      metaMap.set(artifactId, meta);
      return meta;
    } catch (error) {
      const meta: ArtifactMeta = {
        title: fallbackTitle || artifactId,
        imageUrl: '',
        period: '',
        museum: ''
      };
      metaMap.set(artifactId, meta);
      return meta;
    }
  }

  private static async mapFavorites(
    records: BackendFavoriteRecord[],
    localFavorites: FavoriteItem[]
  ): Promise<FavoriteItem[]> {
    const metaMap = InteractionService.buildMetaFromFavoriteItems(localFavorites);
    const list: FavoriteItem[] = [];
    for (let index = 0; index < records.length; index += 1) {
      const record = records[index];
      const artifactId = InteractionService.getStringValue(record, ['artifactId', 'objectId']);
      if (!artifactId) {
        continue;
      }
      const title = InteractionService.getStringValue(record, ['artifactTitle', 'title']);
      const directImageUrl = InteractionService.getStringValue(record, ['imageUrl']);
      const directPeriod = InteractionService.getStringValue(record, ['period']);
      const directMuseum = InteractionService.getStringValue(record, ['museum']);
      if (directImageUrl || directPeriod || directMuseum || title) {
        metaMap.set(artifactId, {
          title: title || artifactId,
          imageUrl: directImageUrl,
          period: directPeriod,
          museum: directMuseum
        });
      }
      const meta = await InteractionService.resolveArtifactMeta(artifactId, metaMap, title);
      list.push({
        artifactId: artifactId,
        title: title || meta.title || artifactId,
        imageUrl: meta.imageUrl,
        period: meta.period,
        museum: meta.museum,
        groupName: InteractionService.getStringValue(record, ['groupName']) || InteractionService.getDefaultGroup(),
        createdAt: InteractionService.normalizeTime(
          InteractionService.getStringValue(record, ['createTime', 'createdAt'])
        )
      });
    }
    return InteractionService.sortByCreatedAtDesc(list);
  }

  private static async mapLikes(records: BackendLikeRecord[], localLikes: LikeItem[]): Promise<LikeItem[]> {
    const metaMap = InteractionService.buildMetaFromLikeItems(localLikes);
    const list: LikeItem[] = [];
    for (let index = 0; index < records.length; index += 1) {
      const record = records[index];
      const artifactId = InteractionService.getStringValue(record, ['artifactId', 'objectId']);
      if (!artifactId) {
        continue;
      }
      const title = InteractionService.getStringValue(record, ['artifactTitle', 'title']);
      const directImageUrl = InteractionService.getStringValue(record, ['imageUrl']);
      const directPeriod = InteractionService.getStringValue(record, ['period']);
      const directMuseum = InteractionService.getStringValue(record, ['museum']);
      if (directImageUrl || directPeriod || directMuseum || title) {
        metaMap.set(artifactId, {
          title: title || artifactId,
          imageUrl: directImageUrl,
          period: directPeriod,
          museum: directMuseum
        });
      }
      const meta = await InteractionService.resolveArtifactMeta(artifactId, metaMap, title);
      list.push({
        artifactId: artifactId,
        title: title || meta.title || artifactId,
        imageUrl: meta.imageUrl,
        period: meta.period,
        museum: meta.museum,
        likedAt: InteractionService.normalizeTime(
          InteractionService.getStringValue(record, ['likedAt', 'createTime'])
        )
      });
    }
    return [...list].sort((left: LikeItem, right: LikeItem) => {
      const leftTime = new Date(left.likedAt).getTime();
      const rightTime = new Date(right.likedAt).getTime();
      return rightTime - leftTime;
    });
  }

  private static async mapHistory(records: BackendHistoryRecord[], localHistory: HistoryItem[]): Promise<HistoryItem[]> {
    const metaMap = InteractionService.buildMetaFromHistoryItems(localHistory);
    const list: HistoryItem[] = [];
    for (let index = 0; index < records.length; index += 1) {
      const record = records[index];
      const artifactId = InteractionService.getStringValue(record, ['artifactId', 'objectId']);
      if (!artifactId) {
        continue;
      }
      const title = InteractionService.getStringValue(record, ['artifactTitle', 'title']);
      const directImageUrl = InteractionService.getStringValue(record, ['imageUrl']);
      const directPeriod = InteractionService.getStringValue(record, ['period']);
      const directMuseum = InteractionService.getStringValue(record, ['museum']);
      if (directImageUrl || directPeriod || directMuseum || title) {
        metaMap.set(artifactId, {
          title: title || artifactId,
          imageUrl: directImageUrl,
          period: directPeriod,
          museum: directMuseum
        });
      }
      const meta = await InteractionService.resolveArtifactMeta(artifactId, metaMap, title);
      list.push({
        artifactId: artifactId,
        title: title || meta.title || artifactId,
        imageUrl: meta.imageUrl,
        period: meta.period,
        museum: meta.museum,
        viewedAt: InteractionService.normalizeTime(
          InteractionService.getStringValue(record, ['viewedAt', 'createTime'])
        )
      });
    }
    return [...list].sort((left: HistoryItem, right: HistoryItem) => {
      const leftTime = new Date(left.viewedAt).getTime();
      const rightTime = new Date(right.viewedAt).getTime();
      return rightTime - leftTime;
    });
  }

  private static mapComment(
    record: BackendCommentRecord,
    fallbackArtifactId: string = '',
    fallbackStatus: ReviewStatus = ReviewStatus.Pending
  ): CommentItem | null {
    const id = InteractionService.getStringValue(record, ['objectId', 'commentId', 'id']);
    const artifactId = InteractionService.getStringValue(record, ['artifactId', 'objectRelicId']) || fallbackArtifactId;
    if (!id || !artifactId) {
      return null;
    }
    const rawStatus = InteractionService.getStringValue(record, ['status', 'auditStatus']);
    return {
      id: id,
      artifactId: artifactId,
      artifactTitle: InteractionService.getStringValue(record, ['artifactTitle', 'title']),
      username: InteractionService.getStringValue(record, ['username', 'userName', 'nickname']) || '匿名用户',
      content: InteractionService.getStringValue(record, ['content']),
      createdAt: InteractionService.normalizeTime(
        InteractionService.getStringValue(record, ['createTime', 'createdAt'])
      ),
      status: rawStatus ? InteractionService.toReviewStatus(rawStatus) : fallbackStatus,
      parentId: InteractionService.getStringValue(record, ['parentId', 'parentCommentId']),
      replyTo: InteractionService.getStringValue(record, ['replyTo', 'replyToUser']),
      likeCount: InteractionService.getNumberValue(record, ['likeCount']),
      likedByCurrentUser: InteractionService.getBooleanValue(record, ['isLiked', 'liked'])
    };
  }

  private static mapCommentThread(
    record: BackendCommentRecord,
    artifactId: string = '',
    fallbackStatus: ReviewStatus = ReviewStatus.Pending
  ): CommentItem[] {
    const result: CommentItem[] = [];
    const parent = InteractionService.mapComment(record, artifactId, fallbackStatus);
    if (!parent) {
      return result;
    }
    result.push(parent);
    const replies = record.replies || [];
    for (let index = 0; index < replies.length; index += 1) {
      const replyRecord = replies[index];
      const replyId = InteractionService.getStringValue(replyRecord, ['objectId', 'commentId', 'id']);
      if (!replyId) {
        continue;
      }
      const replyItem: CommentItem = {
        id: replyId,
        artifactId: parent.artifactId,
        artifactTitle: parent.artifactTitle,
        username: InteractionService.getStringValue(replyRecord, ['username', 'userName', 'nickname']) || '匿名用户',
        content: InteractionService.getStringValue(replyRecord, ['content']),
        createdAt: InteractionService.normalizeTime(
          InteractionService.getStringValue(replyRecord, ['createTime', 'createdAt'])
        ),
        status: fallbackStatus,
        parentId: parent.id,
        replyTo: parent.username,
        likeCount: InteractionService.getNumberValue(replyRecord, ['likeCount']),
        likedByCurrentUser: InteractionService.getBooleanValue(replyRecord, ['isLiked', 'liked'])
      };
      result.push(replyItem);
    }
    return result;
  }

  private static mapUpload(record: BackendUploadRecord): UploadedPhotoItem | null {
    const id = InteractionService.getStringValue(record, ['uploadId', 'objectId', 'id']);
    if (!id) {
      return null;
    }
    return {
      id: id,
      artifactId: InteractionService.getStringValue(record, ['artifactId']),
      artifactTitle: InteractionService.getStringValue(record, ['artifactTitle', 'title']),
      username: InteractionService.getStringValue(record, ['username', 'userName']),
      imageUri: InteractionService.getStringValue(record, ['imageUrl', 'photoUrl']),
      location: InteractionService.getStringValue(record, ['location']),
      description: InteractionService.getStringValue(record, ['description']),
      createdAt: InteractionService.normalizeTime(
        InteractionService.getStringValue(record, ['createTime', 'createdAt'])
      ),
      status: InteractionService.toReviewStatus(
        InteractionService.getStringValue(record, ['status', 'auditStatus']) || 'PENDING'
      )
    };
  }

  private static validateComment(content: string): string {
    const trimmed = content.trim();
    if (!trimmed) {
      return '评论内容不能为空';
    }
    if (trimmed.length < 2) {
      return '评论至少输入 2 个字';
    }
    if (trimmed.length > 200) {
      return '评论请控制在 200 字以内';
    }
    if (InteractionService.BLOCKED_WORDS.some((word: string) => trimmed.indexOf(word) > -1)) {
      return '评论包含敏感词，请修改后再试';
    }
    return '';
  }

  static async recordHistory(artifact: Artifact, username: string): Promise<void> {
    await interactionStore.recordHistory(artifact, username);
    if (!username) {
      return;
    }
    try {
      const body: RecordHistoryRequestBody = {
        artifactId: artifact.id,
        objectId: artifact.id,
        artifactTitle: artifact.title,
        title: artifact.title
      };
      await HttpApi.post<ApiResponse<Object>>(
        `/users/${encodeURIComponent(username)}/history`,
        body
      );
    } catch (error) {
      console.error(`[InteractionService] 同步浏览记录失败 ${JSON.stringify(error)}`);
    }
  }

  static async getHistory(username: string): Promise<HistoryItem[]> {
    const localHistory = await interactionStore.getHistory(username);
    if (!username) {
      return localHistory;
    }
    try {
      const res = await HttpApi.get<ApiResponse<Object | BackendHistoryRecord[]>>(
        `/users/${encodeURIComponent(username)}/history`
      );
      if (res.code !== 200) {
        throw new Error(res.message || '获取浏览记录失败');
      }
      const records = InteractionService.extractList<BackendHistoryRecord>(res.data, ['history']);
      return InteractionService.mapHistory(records, localHistory);
    } catch (error) {
      console.error(`[InteractionService] 获取浏览记录失败，改用本地兜底 ${JSON.stringify(error)}`);
      return localHistory;
    }
  }

  static async getLikeSummary(artifactId: string, username: string = ''): Promise<InteractionSummary> {
    return interactionStore.getLikeSummary(artifactId, username);
  }

  static async syncLikeCountFromArtifact(artifact: Artifact): Promise<void> {
    if (!artifact || typeof artifact.popularity !== 'number' || artifact.popularity < 0) {
      return;
    }
    await interactionStore.setLikeCount(artifact.id, artifact.popularity);
  }

  static async toggleLike(artifact: Artifact, username: string): Promise<InteractionSummary> {
    const localBefore = await interactionStore.getLikeSummary(artifact.id, username);
    const targetActive = !localBefore.active;
    try {
      const body: EmptyRequestBody = {};
      const res = await HttpApi.post<ApiResponse<ToggleResponseData>>(
        `/artifacts/${encodeURIComponent(artifact.id)}/likes`,
        body
      );
      if (res.code !== 200) {
        throw new Error(res.message || '点赞失败');
      }
      let finalActive = targetActive;
      let useLocalCount = false;
      if (res.data && res.data.isLiked !== undefined) {
        finalActive = !!res.data.isLiked;
      }
      if (finalActive !== targetActive) {
        console.warn(`[InteractionService] 点赞状态与用户操作不一致，使用本地兜底 artifactId=${artifact.id}`);
        finalActive = targetActive;
        useLocalCount = true;
      }
      await interactionStore.syncLikeState(artifact.id, username, finalActive, artifact);
      const localAfter = await interactionStore.getLikeSummary(artifact.id, username);
      let shouldUseRemoteCount = false;
      if (res.data && res.data.likeCount !== undefined && !useLocalCount) {
        if (finalActive && res.data.likeCount >= localAfter.count) {
          shouldUseRemoteCount = true;
        }
        if (!finalActive && res.data.likeCount <= localAfter.count) {
          shouldUseRemoteCount = true;
        }
      }
      if (shouldUseRemoteCount && res.data && res.data.likeCount !== undefined) {
        await interactionStore.setLikeCount(artifact.id, res.data.likeCount);
      }
      const summaryAfterCountSync = await interactionStore.getLikeSummary(artifact.id, username);
      return {
        active: finalActive,
        count: shouldUseRemoteCount ? summaryAfterCountSync.count : localAfter.count
      };
    } catch (error) {
      console.error(`[InteractionService] 点赞接口失败，改用本地兜底 ${JSON.stringify(error)}`);
      return interactionStore.syncLikeState(artifact.id, username, targetActive, artifact);
    }
  }

  static async getLikes(username: string): Promise<LikeItem[]> {
    const localLikes = await interactionStore.getLikes(username);
    if (!username) {
      return localLikes;
    }
    try {
      const res = await HttpApi.get<ApiResponse<Object | BackendLikeRecord[]>>(
        `/users/${encodeURIComponent(username)}/likes`
      );
      if (res.code !== 200) {
        throw new Error(res.message || '获取点赞列表失败');
      }
      const records = InteractionService.extractList<BackendLikeRecord>(res.data, ['likes']);
      const remoteLikes = await InteractionService.mapLikes(records, localLikes);
      const mergedMap = new Map<string, LikeItem>();
      remoteLikes.forEach((item: LikeItem) => {
        mergedMap.set(item.artifactId, item);
      });
      localLikes.forEach((item: LikeItem) => {
        mergedMap.set(item.artifactId, item);
      });
      const result: LikeItem[] = [];
      const candidates = Array.from(mergedMap.values());
      for (let index = 0; index < candidates.length; index += 1) {
        const item = candidates[index];
        const localSummary = await interactionStore.getLikeSummary(item.artifactId, username);
        const hasLocalRecord = await interactionStore.hasLikeRecord(item.artifactId);
        if (localSummary.active || !hasLocalRecord) {
          result.push(item);
        }
      }
      const sortedLikes = [...result].sort((left: LikeItem, right: LikeItem) => {
        const leftTime = new Date(left.likedAt).getTime();
        const rightTime = new Date(right.likedAt).getTime();
        return rightTime - leftTime;
      });
      await interactionStore.savePublicLikes(username, sortedLikes);
      return sortedLikes;
    } catch (error) {
      console.error(`[InteractionService] 获取点赞列表失败，改用本地兜底 ${JSON.stringify(error)}`);
      return localLikes;
    }
  }

  static async removeLike(artifactId: string, username: string): Promise<void> {
    const localSummary = await interactionStore.getLikeSummary(artifactId, username);
    if (!localSummary.active) {
      await interactionStore.removeLike(artifactId, username);
      return;
    }
    try {
      const body: EmptyRequestBody = {};
      const res = await HttpApi.post<ApiResponse<ToggleResponseData>>(
        `/artifacts/${encodeURIComponent(artifactId)}/likes`,
        body
      );
      if (res.code !== 200) {
        throw new Error(res.message || '取消点赞失败');
      }
      const remoteActive = res.data && res.data.isLiked !== undefined ? !!res.data.isLiked : false;
      if (remoteActive) {
        throw new Error('后端仍返回已点赞状态');
      }
      await interactionStore.removeLike(artifactId, username);
    } catch (error) {
      console.error(`[InteractionService] 取消点赞失败，改用本地兜底 ${JSON.stringify(error)}`);
      await interactionStore.removeLike(artifactId, username);
    }
  }

  static async getFavoriteSummary(artifactId: string, username: string = ''): Promise<InteractionSummary> {
    const localSummary = await interactionStore.getFavoriteSummary(artifactId, username);
    if (!username) {
      return localSummary;
    }
    try {
      const favorites = await InteractionService.getFavorites(username);
      return {
        active: favorites.some((item: FavoriteItem) => item.artifactId === artifactId),
        count: localSummary.count
      };
    } catch (error) {
      return localSummary;
    }
  }

  static async toggleFavorite(
    artifact: Artifact,
    username: string,
    groupName: string = FAVORITE_GROUPS[0]
  ): Promise<InteractionSummary> {
    const currentSummary = await InteractionService.getFavoriteSummary(artifact.id, username);

    if (currentSummary.active) {
      return interactionStore.syncFavoriteState(artifact, username, false, groupName);
    }

    try {
      const body: FavoriteRequestBody = {
        artifactId: artifact.id,
        objectId: artifact.id,
        artifactTitle: artifact.title,
        title: artifact.title,
        groupName: groupName
      };
      const res = await HttpApi.post<ApiResponse<ToggleResponseData>>(
        `/users/${encodeURIComponent(username)}/favorites`,
        body
      );
      if (res.code !== 200) {
        throw new Error(res.message || '收藏失败');
      }
      let finalActive = true;
      let useLocalCount = false;
      if (res.data && res.data.isFavorited !== undefined) {
        finalActive = !!res.data.isFavorited;
      }
      if (!finalActive) {
        finalActive = true;
        useLocalCount = true;
      }
      await interactionStore.syncFavoriteState(artifact, username, finalActive, groupName);
      const localAfter = await interactionStore.getFavoriteSummary(artifact.id, username);
      return {
        active: finalActive,
        count: res.data && res.data.favoriteCount !== undefined && !useLocalCount ? res.data.favoriteCount : localAfter.count
      };
    } catch (error) {
      console.error(`[InteractionService] 收藏接口失败，改用本地兜底 ${JSON.stringify(error)}`);
      return interactionStore.syncFavoriteState(artifact, username, true, groupName);
    }
  }

  static async getFavorites(username: string): Promise<FavoriteItem[]> {
    const localFavorites = await interactionStore.getFavorites(username);
    if (!username) {
      return localFavorites;
    }
    try {
      const res = await HttpApi.get<ApiResponse<Object | BackendFavoriteRecord[]>>(
        `/users/${encodeURIComponent(username)}/favorites`
      );
      if (res.code !== 200) {
        throw new Error(res.message || '获取收藏列表失败');
      }
      const records = InteractionService.extractList<BackendFavoriteRecord>(res.data, ['favorites']);
      const remoteFavorites = await InteractionService.mapFavorites(records, localFavorites);
      const removedIds = await interactionStore.getRemovedFavoriteIds(username);
      const mergedMap = new Map<string, FavoriteItem>();
      remoteFavorites.forEach((item: FavoriteItem) => {
        if (removedIds.indexOf(item.artifactId) === -1) {
          mergedMap.set(item.artifactId, item);
        }
      });
      localFavorites.forEach((item: FavoriteItem) => {
        mergedMap.set(item.artifactId, item);
      });
      const mergedFavorites: FavoriteItem[] = [];
      mergedMap.forEach((item: FavoriteItem) => {
        mergedFavorites.push(item);
      });
      const sortedFavorites = mergedFavorites.sort((left: FavoriteItem, right: FavoriteItem) => {
        const leftTime = new Date(left.createdAt).getTime();
        const rightTime = new Date(right.createdAt).getTime();
        return rightTime - leftTime;
      });
      await interactionStore.savePublicFavorites(username, sortedFavorites);
      return sortedFavorites;
    } catch (error) {
      console.error(`[InteractionService] 获取收藏列表失败，改用本地兜底 ${JSON.stringify(error)}`);
      return localFavorites;
    }
  }

  static async getFavoriteGroups(username: string): Promise<string[]> {
    return interactionStore.getFavoriteGroups(username);
  }

  static async addFavoriteGroup(username: string, groupName: string): Promise<string[]> {
    return interactionStore.addFavoriteGroup(username, groupName);
  }

  static async deleteFavoriteGroup(username: string, groupName: string): Promise<string[]> {
    return interactionStore.deleteFavoriteGroup(username, groupName);
  }

  static async getFavoriteGroupForArtifact(username: string, artifactId: string): Promise<string> {
    const favorites = await InteractionService.getFavorites(username);
    const target = favorites.find((item: FavoriteItem) => item.artifactId === artifactId);
    const groups = await interactionStore.getFavoriteGroups(username);
    return target ? target.groupName : (groups.length > 0 ? groups[0] : InteractionService.getDefaultGroup());
  }

  static async getFavoriteGroupSummaries(username: string): Promise<FavoriteGroupSummary[]> {
    const favorites = await InteractionService.getFavorites(username);
    const groups = await interactionStore.getFavoriteGroups(username);
    return groups.map((groupName: string): FavoriteGroupSummary => {
      return {
        name: groupName,
        count: favorites.filter((item: FavoriteItem) => item.groupName === groupName).length,
        isDefault: FAVORITE_GROUPS.indexOf(groupName) > -1
      };
    });
  }

  static async moveFavoriteToGroup(artifactId: string, username: string, groupName: string): Promise<string> {
    const currentGroup = await interactionStore.getFavoriteGroupForArtifact(username, artifactId);
    if (currentGroup === groupName) {
      return currentGroup;
    }
    const favorites = await InteractionService.getFavorites(username);
    const target = favorites.find((item: FavoriteItem) => item.artifactId === artifactId);
    if (target) {
      await interactionStore.ensureFavoriteItem(username, {
        artifactId: target.artifactId,
        title: target.title,
        imageUrl: target.imageUrl,
        period: target.period,
        museum: target.museum,
        groupName: groupName,
        createdAt: target.createdAt
      });
    }
    return interactionStore.moveFavoriteToGroup(artifactId, username, groupName);
  }

  static async removeFavorite(artifactId: string, username: string): Promise<void> {
    return interactionStore.removeFavorite(artifactId, username);
  }

  static async getCommentsForArtifact(artifactId: string, username: string = ''): Promise<CommentItem[]> {
    const localComments = await interactionStore.getCommentsForArtifact(artifactId, username);
    try {
      const res = await HttpApi.get<ApiResponse<Object | BackendCommentRecord[]>>(
        `/artifacts/${encodeURIComponent(artifactId)}/comments`
      );
      if (res.code !== 200) {
        throw new Error(res.message || '获取评论列表失败');
      }
      const records = InteractionService.extractList<BackendCommentRecord>(res.data, ['comments']);
      const remoteComments: CommentItem[] = [];
      records.forEach((item: BackendCommentRecord) => {
        const thread = InteractionService.mapCommentThread(item, artifactId, ReviewStatus.Approved);
        for (let index = 0; index < thread.length; index += 1) {
          remoteComments.push(thread[index]);
        }
      });
      await InteractionService.syncPublicCommentsFromArtifact(remoteComments);
      if (!username) {
        return InteractionService.sortByCreatedAtDesc(remoteComments);
      }
      const localPending = localComments.filter((item: CommentItem) => item.status !== ReviewStatus.Approved);
      return InteractionService.mergeComments(remoteComments, localPending);
    } catch (error) {
      console.error(`[InteractionService] 获取文物评论失败，改用本地兜底 ${JSON.stringify(error)}`);
      return localComments;
    }
  }

  static async toggleCommentLike(commentId: string, username: string): Promise<InteractionSummary> {
    const localBefore = await interactionStore.getCommentLikeSummary(commentId, username);
    try {
      const body: EmptyRequestBody = {};
      const res = await HttpApi.post<ApiResponse<ToggleResponseData>>(
        `/comments/${encodeURIComponent(commentId)}/likes`,
        body
      );
      if (res.code !== 200) {
        throw new Error(res.message || '评论点赞失败');
      }
      const remoteActive = res.data && res.data.isLiked !== undefined ? !!res.data.isLiked : !localBefore.active;
      if (remoteActive !== localBefore.active) {
        await interactionStore.syncCommentLikeState(commentId, username, remoteActive);
      }
      const localAfter = await interactionStore.getCommentLikeSummary(commentId, username);
      return {
        active: remoteActive,
        count: res.data && res.data.likeCount !== undefined ? res.data.likeCount : localAfter.count
      };
    } catch (error) {
      console.error(`[InteractionService] 评论点赞失败，改用本地兜底 ${JSON.stringify(error)}`);
      return interactionStore.toggleCommentLike(commentId, username);
    }
  }

  static async addComment(
    artifact: Artifact,
    username: string,
    content: string,
    parentId: string = '',
    replyTo: string = ''
  ): Promise<CommentResult> {
    const message = InteractionService.validateComment(content);
    if (message) {
      return { ok: false, message: message };
    }

    try {
      const body: CommentRequestBody = {
        artifactId: artifact.id,
        objectId: artifact.id,
        content: content.trim(),
        parentId: parentId,
        replyTo: replyTo
      };
      const res = await HttpApi.post<ApiResponse<Object>>(
        `/artifacts/${encodeURIComponent(artifact.id)}/comments`,
        body
      );
      if (res.code !== 200) {
        throw new Error(res.message || '评论提交失败');
      }
      await interactionStore.addCommentMirror(artifact, username, content, parentId, replyTo);
      return {
        ok: true,
        message: res.message || '评论已提交'
      };
    } catch (error) {
      console.error(`[InteractionService] 评论接口失败，改用本地兜底 ${JSON.stringify(error)}`);
      return interactionStore.addComment(artifact, username, content, parentId, replyTo);
    }
  }

  static async getUserComments(username: string): Promise<CommentItem[]> {
    const localComments = await interactionStore.getUserComments(username);
    if (!username) {
      return localComments;
    }
    try {
      const res = await HttpApi.get<ApiResponse<Object | BackendCommentRecord[]>>(
        `/users/${encodeURIComponent(username)}/comments`
      );
      if (res.code !== 200) {
        throw new Error(res.message || '获取我的评论失败');
      }
      const records = InteractionService.extractList<BackendCommentRecord>(res.data, ['comments']);
      const remoteComments = records
        .map((item: BackendCommentRecord) => InteractionService.mapComment(item))
        .filter((item: CommentItem | null) => item !== null) as CommentItem[];
      const mergedComments = InteractionService.mergeComments(remoteComments, localComments);
      await interactionStore.savePublicComments(username, mergedComments);
      return mergedComments;
    } catch (error) {
      console.error(`[InteractionService] 获取我的评论失败，改用本地兜底 ${JSON.stringify(error)}`);
      return localComments;
    }
  }

  static async addUpload(context: common.UIAbilityContext, draft: UploadDraft): Promise<ActionResult> {
    if (!draft.artifactId) {
      await interactionStore.addUpload(draft);
      return {
        ok: true,
        message: '照片已上传，等待审核'
      };
    }

    try {
      await HttpApi.uploadFile(
        context,
        `/artifacts/${encodeURIComponent(draft.artifactId)}/uploads`,
        draft.imageUri,
        'file'
      );
      return {
        ok: true,
        message: '照片已上传，等待审核'
      };
    } catch (error) {
      console.error(`[InteractionService] 上传照片失败，改用本地兜底 ${JSON.stringify(error)}`);
      await interactionStore.addUpload(draft);
      return {
        ok: true,
        message: '照片已上传，等待审核'
      };
    }
  }

  static async getUploads(username: string): Promise<UploadedPhotoItem[]> {
    const localUploads = await interactionStore.getUploads(username);
    if (!username) {
      return localUploads;
    }
    try {
      const res = await HttpApi.get<ApiResponse<Object | BackendUploadRecord[]>>(
        `/users/${encodeURIComponent(username)}/uploads`
      );
      if (res.code !== 200) {
        throw new Error(res.message || '获取上传列表失败');
      }
      const records = InteractionService.extractList<BackendUploadRecord>(res.data, ['uploads']);
      const remoteUploads = records
        .map((item: BackendUploadRecord) => InteractionService.mapUpload(item))
        .filter((item: UploadedPhotoItem | null) => item !== null) as UploadedPhotoItem[];
      const localPending = localUploads.filter((item: UploadedPhotoItem) => item.status !== ReviewStatus.Approved);
      const mergedUploads = InteractionService.mergeById(remoteUploads, localPending);
      await interactionStore.savePublicUploads(username, mergedUploads);
      return mergedUploads;
    } catch (error) {
      console.error(`[InteractionService] 获取上传列表失败，改用本地兜底 ${JSON.stringify(error)}`);
      return localUploads;
    }
  }
}

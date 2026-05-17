import { Artifact } from '../models/Artifact';
import {
  CommentItem,
  DEFAULT_PRIVACY_SETTINGS,
  FAVORITE_GROUPS,
  FavoriteItem,
  HistoryItem,
  InteractionSummary,
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

class InteractionStore {
  private readonly likeKey = 'pm.likes';
  private readonly favoriteKey = 'pm.favorites';
  private readonly commentKey = 'pm.comments';
  private readonly uploadKey = 'pm.uploads';
  private readonly historyKey = 'pm.history';
  private readonly privacyKey = 'pm.privacy';

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

  private buildLikeBaseCount(artifactId: string): number {
    const seed = Number(artifactId);
    return Number.isNaN(seed) ? 16 : 16 + seed * 5;
  }

  private buildFavoriteBaseCount(artifactId: string): number {
    const seed = Number(artifactId);
    return Number.isNaN(seed) ? 8 : 8 + seed * 3;
  }

  private getSeedComments(artifactId: string): CommentItem[] {
    return [
      {
        id: `seed-${artifactId}-1`,
        artifactId: artifactId,
        artifactTitle: '',
        username: '文博爱好者',
        content: '器物信息很完整，适合配合语音讲解一起看。',
        createdAt: '2026-05-10T10:00:00.000Z',
        status: ReviewStatus.Approved
      },
      {
        id: `seed-${artifactId}-2`,
        artifactId: artifactId,
        artifactTitle: '',
        username: '海外馆藏观察员',
        content: '如果能补充更多同朝代关联文物，会更方便横向比较。',
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

  async getLikeSummary(artifactId: string, username: string = ''): Promise<InteractionSummary> {
    const likeObj = await this.getJsonValue<Record<string, string[]>>(this.likeKey, {});
    const likeMap = this.objectToMap<string[]>(likeObj);
    const users = likeMap.get(artifactId) || [];
    return {
      active: username ? users.indexOf(username) > -1 : false,
      count: this.buildLikeBaseCount(artifactId) + users.length
    };
  }

  async toggleLike(artifactId: string, username: string): Promise<InteractionSummary> {
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
    return this.getLikeSummary(artifactId, username);
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

  async toggleFavorite(artifact: Artifact, username: string, groupName: string = FAVORITE_GROUPS[0]): Promise<InteractionSummary> {
    const favoriteObj = await this.getJsonValue<Record<string, FavoriteItem[]>>(this.favoriteKey, {});
    const favoriteMap = this.objectToMap<FavoriteItem[]>(favoriteObj);
    const list = favoriteMap.get(username) || [];
    const existingIndex = list.findIndex((item: FavoriteItem) => item.artifactId === artifact.id);
    if (existingIndex > -1) {
      list.splice(existingIndex, 1);
    } else {
      list.unshift(this.buildFavoriteItem(artifact, groupName));
    }
    favoriteMap.set(username, list);
    await this.setJsonValue(this.favoriteKey, this.mapToObject(favoriteMap));
    return this.getFavoriteSummary(artifact.id, username);
  }

  async getFavorites(username: string): Promise<FavoriteItem[]> {
    const favoriteObj = await this.getJsonValue<Record<string, FavoriteItem[]>>(this.favoriteKey, {});
    const favoriteMap = this.objectToMap<FavoriteItem[]>(favoriteObj);
    return favoriteMap.get(username) || [];
  }

  async removeFavorite(artifactId: string, username: string): Promise<void> {
    const favoriteObj = await this.getJsonValue<Record<string, FavoriteItem[]>>(this.favoriteKey, {});
    const favoriteMap = this.objectToMap<FavoriteItem[]>(favoriteObj);
    favoriteMap.set(username, (favoriteMap.get(username) || []).filter((item: FavoriteItem) => item.artifactId !== artifactId));
    await this.setJsonValue(this.favoriteKey, this.mapToObject(favoriteMap));
  }

  async cycleFavoriteGroup(artifactId: string, username: string): Promise<string> {
    const favoriteObj = await this.getJsonValue<Record<string, FavoriteItem[]>>(this.favoriteKey, {});
    const favoriteMap = this.objectToMap<FavoriteItem[]>(favoriteObj);
    const favorites = favoriteMap.get(username) || [];
    const target = favorites.find((item: FavoriteItem) => item.artifactId === artifactId);
    if (!target) {
      return FAVORITE_GROUPS[0];
    }
    const currentIndex = FAVORITE_GROUPS.indexOf(target.groupName);
    const nextIndex = currentIndex > -1 ? (currentIndex + 1) % FAVORITE_GROUPS.length : 0;
    target.groupName = FAVORITE_GROUPS[nextIndex];
    favoriteMap.set(username, favorites);
    await this.setJsonValue(this.favoriteKey, this.mapToObject(favoriteMap));
    return target.groupName;
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

  async getCommentsForArtifact(artifactId: string): Promise<CommentItem[]> {
    const comments = await this.getJsonValue<CommentItem[]>(this.commentKey, []);
    const current = comments.filter((item: CommentItem) => item.artifactId === artifactId);
    return [...this.getSeedComments(artifactId), ...current];
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
    if (BLOCKED_WORDS.some((word: string) => trimmed.indexOf(word) > -1)) {
      const result: CommentResult = { ok: false, message: '评论包含敏感词，请修改后再试' };
      return result;
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
    const result: CommentResult = { ok: true, message: '评论已提交，等待审核' };
    return result;
  }

  async getUserComments(username: string): Promise<CommentItem[]> {
    const comments = await this.getJsonValue<CommentItem[]>(this.commentKey, []);
    return comments.filter((item: CommentItem) => item.username === username);
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
  }

  async getUploads(username: string): Promise<UploadedPhotoItem[]> {
    const uploads = await this.getJsonValue<UploadedPhotoItem[]>(this.uploadKey, []);
    return uploads.filter((item: UploadedPhotoItem) => item.username === username);
  }

  async getPrivacy(username: string): Promise<PrivacySettings> {
    if (!username) {
      return DEFAULT_PRIVACY_SETTINGS;
    }
    const privacyObj = await this.getJsonValue<Record<string, PrivacySettings>>(this.privacyKey, {});
    const privacyMap = this.objectToMap<PrivacySettings>(privacyObj);
    return privacyMap.get(username) || DEFAULT_PRIVACY_SETTINGS;
  }

  async savePrivacy(username: string, privacy: PrivacySettings): Promise<void> {
    const privacyObj = await this.getJsonValue<Record<string, PrivacySettings>>(this.privacyKey, {});
    const privacyMap = this.objectToMap<PrivacySettings>(privacyObj);
    privacyMap.set(username, privacy);
    await this.setJsonValue(this.privacyKey, this.mapToObject(privacyMap));
  }

  async getStats(username: string): Promise<UserInteractionStats> {
    const favorites = await this.getFavorites(username);
    const uploads = await this.getUploads(username);
    const comments = await this.getUserComments(username);
    const history = await this.getHistory(username);
    const likeObj = await this.getJsonValue<Record<string, string[]>>(this.likeKey, {});
    const likeMap = this.objectToMap<string[]>(likeObj);

    let likes = 0;
    likeMap.forEach((users: string[]) => {
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
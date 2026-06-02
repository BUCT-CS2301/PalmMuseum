import { HttpApi, HttpQueryParam } from '../network/HttpApi';
import {
  CommentItem,
  FavoriteGroupSummary,
  FavoriteItem,
  HistoryItem,
  InteractionSummary,
  LikeItem,
  PrivacySettings,
  ReviewStatus
} from '../models/InteractionModels';

interface ApiResponse<T> {
  code: number;
  message?: string;
  data?: T;
}

interface FavoriteGroupDto {
  groupName: string;
  createTime?: string;
}

interface FavoriteGroupSummaryDto {
  groupName: string;
  count: number;
}

interface FavoriteRecordDto {
  artifactId?: string;
  objectId?: string;
  title?: string;
  imageUrl?: string;
  period?: string;
  museum?: string;
  groupName?: string;
  createTime?: string;
  createdAt?: string;
}

interface LikeRecordDto {
  artifactId?: string;
  objectId?: string;
  title?: string;
  imageUrl?: string;
  period?: string;
  museum?: string;
  likedAt?: string;
  createTime?: string;
}

interface HistoryRecordDto {
  artifactId?: string;
  objectId?: string;
  title?: string;
  imageUrl?: string;
  period?: string;
  museum?: string;
  viewedAt?: string;
  browseTime?: string;
}

interface CommentDto {
  objectId?: string;
  artifactId?: string;
  artifactTitle?: string;
  userId?: string;
  userName?: string;
  userAvatar?: string;
  content?: string;
  likeCount?: number;
  replyCount?: number;
  createTime?: string;
  createdAt?: string;
  status?: string;
  parentId?: string;
  replyTo?: string;
  likedByCurrentUser?: boolean;
  replies?: CommentDto[];
}

interface InteractionSummaryDto {
  artifactId?: string;
  likeCount?: number;
  favoriteCount?: number;
  commentCount?: number;
  viewCount?: number;
  isLiked?: boolean;
  isFavorited?: boolean;
  favoriteGroup?: string;
}

interface ToggleLikeDto {
  likeCount?: number;
  isLiked?: boolean;
}

interface ToggleFavoriteDto {
  artifactId?: string;
  groupName?: string | null;
  isFavorited?: boolean;
}

interface PrivacyDto {
  favoritesVisible?: boolean;
  likesVisible?: boolean;
  commentsVisible?: boolean;
  uploadsVisible?: boolean;
}

interface CommentPostResultDto {
  objectId?: string;
  status?: string;
  message?: string;
}

interface ItemCollectionDto<T> {
  items?: T[];
  records?: T[];
}

interface EmptyBody {
}

interface FavoriteGroupCreateBody {
  groupName: string;
}

interface FavoriteCreateBody {
  artifactId: string;
  groupName: string;
}

interface FavoriteMoveBody {
  groupName: string;
}

interface CommentCreateBody {
  content: string;
  parentId: string | null;
}

interface HistoryCreateBody {
  artifactId: string;
}

interface PrivacySaveBody {
  favoritesVisible: boolean;
  likesVisible: boolean;
  commentsVisible: boolean;
  uploadsVisible: boolean;
}

interface PageRequestQuery {
  page: string;
  size: string;
}

const DEFAULT_GROUP_LABEL = '默认收藏夹';
const DEFAULT_GROUP_SERVER_VALUE = 'default';

export class InteractionApiService {
  private static buildPageQuery(): HttpQueryParam[] {
    const pageParam: HttpQueryParam = {
      key: 'page',
      value: '1'
    };
    const sizeParam: HttpQueryParam = {
      key: 'size',
      value: '100'
    };
    return [pageParam, sizeParam];
  }

  private static encodePathSegment(value: string): string {
    return encodeURIComponent(value);
  }

  static toServerGroupName(groupName: string): string {
    const trimmed = groupName.trim();
    if (!trimmed || trimmed === DEFAULT_GROUP_LABEL) {
      return DEFAULT_GROUP_SERVER_VALUE;
    }
    return trimmed;
  }

  static toDisplayGroupName(groupName: string): string {
    if (!groupName || groupName === DEFAULT_GROUP_SERVER_VALUE) {
      return DEFAULT_GROUP_LABEL;
    }
    return groupName;
  }

  private static pickItems<T>(data: Object | undefined): T[] {
    if (!data) {
      return [];
    }
    const arrayData = data as Array<T>;
    if (Array.isArray(arrayData)) {
      return arrayData;
    }
    const recordData = data as ItemCollectionDto<T>;
    const items = recordData.items as Array<T>;
    if (Array.isArray(items)) {
      return items;
    }
    const records = recordData.records as Array<T>;
    if (Array.isArray(records)) {
      return records;
    }
    return [];
  }

  private static mapReviewStatus(status?: string): ReviewStatus {
    const normalized = status ? status.toUpperCase() : '';
    if (normalized === 'APPROVED' || normalized === 'APPROVE') {
      return ReviewStatus.Approved;
    }
    return ReviewStatus.Pending;
  }

  private static mergeFavoriteRecord(item: FavoriteRecordDto, snapshot?: FavoriteItem): FavoriteItem {
    const artifactId = item.artifactId || item.objectId || (snapshot ? snapshot.artifactId : '');
    const result: FavoriteItem = {
      artifactId: artifactId,
      title: item.title || (snapshot ? snapshot.title : artifactId),
      imageUrl: item.imageUrl || (snapshot ? snapshot.imageUrl : ''),
      period: item.period || (snapshot ? snapshot.period : ''),
      museum: item.museum || (snapshot ? snapshot.museum : ''),
      groupName: InteractionApiService.toDisplayGroupName(item.groupName || (snapshot ? snapshot.groupName : DEFAULT_GROUP_SERVER_VALUE)),
      createdAt: item.createTime || item.createdAt || (snapshot ? snapshot.createdAt : new Date().toISOString())
    };
    return result;
  }

  private static mergeLikeRecord(item: LikeRecordDto, snapshot?: LikeItem): LikeItem {
    const artifactId = item.artifactId || item.objectId || (snapshot ? snapshot.artifactId : '');
    const result: LikeItem = {
      artifactId: artifactId,
      title: item.title || (snapshot ? snapshot.title : artifactId),
      imageUrl: item.imageUrl || (snapshot ? snapshot.imageUrl : ''),
      period: item.period || (snapshot ? snapshot.period : ''),
      museum: item.museum || (snapshot ? snapshot.museum : ''),
      likedAt: item.likedAt || item.createTime || (snapshot ? snapshot.likedAt : new Date().toISOString())
    };
    return result;
  }

  private static mergeHistoryRecord(item: HistoryRecordDto, snapshot?: HistoryItem): HistoryItem {
    const artifactId = item.artifactId || item.objectId || (snapshot ? snapshot.artifactId : '');
    const result: HistoryItem = {
      artifactId: artifactId,
      title: item.title || (snapshot ? snapshot.title : artifactId),
      imageUrl: item.imageUrl || (snapshot ? snapshot.imageUrl : ''),
      period: item.period || (snapshot ? snapshot.period : ''),
      museum: item.museum || (snapshot ? snapshot.museum : ''),
      viewedAt: item.viewedAt || item.browseTime || (snapshot ? snapshot.viewedAt : new Date().toISOString())
    };
    return result;
  }

  private static flattenComments(items: CommentDto[], artifactId: string): CommentItem[] {
    const result: CommentItem[] = [];
    items.forEach((item: CommentDto) => {
      const rootId = item.objectId || '';
      const rootUserName = item.userName || '匿名用户';
      const rootComment: CommentItem = {
        id: rootId,
        artifactId: item.artifactId || artifactId,
        artifactTitle: item.artifactTitle || '',
        username: rootUserName,
        content: item.content || '',
        createdAt: item.createTime || item.createdAt || new Date().toISOString(),
        status: InteractionApiService.mapReviewStatus(item.status),
        likeCount: item.likeCount || 0,
        likedByCurrentUser: item.likedByCurrentUser === true
      };
      result.push(rootComment);

      const replies = item.replies || [];
      replies.forEach((reply: CommentDto) => {
        const replyComment: CommentItem = {
          id: reply.objectId || '',
          artifactId: reply.artifactId || artifactId,
          artifactTitle: reply.artifactTitle || '',
          username: reply.userName || '匿名用户',
          content: reply.content || '',
          createdAt: reply.createTime || reply.createdAt || new Date().toISOString(),
          status: InteractionApiService.mapReviewStatus(reply.status),
          parentId: reply.parentId || rootId,
          replyTo: reply.replyTo || rootUserName,
          likeCount: reply.likeCount || 0,
          likedByCurrentUser: reply.likedByCurrentUser === true
        };
        result.push(replyComment);
      });
    });
    return result;
  }

  static async getFavoriteGroups(username: string): Promise<string[]> {
    const res = await HttpApi.get<ApiResponse<FavoriteGroupDto[]>>(`/users/${username}/favorite-groups`);
    if (res.code !== 200 || !res.data) {
      throw new Error(res.message || '获取收藏夹列表失败');
    }
    const groups = (res.data as FavoriteGroupDto[]).map((item: FavoriteGroupDto) => {
      return InteractionApiService.toDisplayGroupName(item.groupName);
    });
    if (groups.length === 0) {
      return [DEFAULT_GROUP_LABEL];
    }
    return groups;
  }

  static async addFavoriteGroup(username: string, groupName: string): Promise<string[]> {
    const body: FavoriteGroupCreateBody = {
      groupName: InteractionApiService.toServerGroupName(groupName)
    };
    const res = await HttpApi.post<ApiResponse<FavoriteGroupDto>>(`/users/${username}/favorite-groups`, body);
    if (res.code !== 200) {
      throw new Error(res.message || '新建收藏夹失败');
    }
    return InteractionApiService.getFavoriteGroups(username);
  }

  static async deleteFavoriteGroup(username: string, groupName: string): Promise<string[]> {
    const remoteName = InteractionApiService.toServerGroupName(groupName);
    const encodedName = InteractionApiService.encodePathSegment(remoteName);
    const res = await HttpApi.delete<ApiResponse<ToggleFavoriteDto>>(`/users/${username}/favorite-groups/${encodedName}`);
    if (res.code !== 200) {
      throw new Error(res.message || '删除收藏夹失败');
    }
    return InteractionApiService.getFavoriteGroups(username);
  }

  static async getFavoriteGroupSummaries(username: string): Promise<FavoriteGroupSummary[]> {
    const res = await HttpApi.get<ApiResponse<FavoriteGroupSummaryDto[]>>(`/users/${username}/favorite-groups/summary`);
    if (res.code !== 200 || !res.data) {
      throw new Error(res.message || '获取收藏夹统计失败');
    }
    return (res.data as FavoriteGroupSummaryDto[]).map((item: FavoriteGroupSummaryDto): FavoriteGroupSummary => {
      const displayName = InteractionApiService.toDisplayGroupName(item.groupName);
      const summary: FavoriteGroupSummary = {
        name: displayName,
        count: item.count || 0,
        isDefault: displayName === DEFAULT_GROUP_LABEL
      };
      return summary;
    });
  }

  static async getFavorites(username: string, snapshots: FavoriteItem[] = []): Promise<FavoriteItem[]> {
    const query = InteractionApiService.buildPageQuery();
    const res = await HttpApi.get<ApiResponse<Object>>(`/users/${username}/favorites`, query);
    if (res.code !== 200) {
      throw new Error(res.message || '获取收藏列表失败');
    }
    const items = InteractionApiService.pickItems<FavoriteRecordDto>(res.data);
    return items.map((item: FavoriteRecordDto): FavoriteItem => {
      const artifactId = item.artifactId || item.objectId || '';
      const snapshot = snapshots.find((local: FavoriteItem) => local.artifactId === artifactId);
      return InteractionApiService.mergeFavoriteRecord(item, snapshot);
    });
  }

  static async addFavorite(username: string, artifactId: string, groupName: string): Promise<ToggleFavoriteDto> {
    const body: FavoriteCreateBody = {
      artifactId: artifactId,
      groupName: InteractionApiService.toServerGroupName(groupName)
    };
    const res = await HttpApi.post<ApiResponse<ToggleFavoriteDto>>(`/users/${username}/favorites`, body);
    if (res.code !== 200 || !res.data) {
      throw new Error(res.message || '收藏失败');
    }
    return res.data;
  }

  static async moveFavorite(username: string, artifactId: string, groupName: string): Promise<ToggleFavoriteDto> {
    const body: FavoriteMoveBody = {
      groupName: InteractionApiService.toServerGroupName(groupName)
    };
    const res = await HttpApi.put<ApiResponse<ToggleFavoriteDto>>(`/users/${username}/favorites/${artifactId}/group`, body);
    if (res.code !== 200 || !res.data) {
      throw new Error(res.message || '修改收藏分组失败');
    }
    return res.data;
  }

  static async removeFavorite(username: string, artifactId: string): Promise<void> {
    const res = await HttpApi.delete<ApiResponse<ToggleFavoriteDto>>(`/users/${username}/favorites/${artifactId}`);
    if (res.code !== 200) {
      throw new Error(res.message || '取消收藏失败');
    }
  }

  static async getArtifactInteractionSummary(artifactId: string): Promise<InteractionSummaryDto> {
    const res = await HttpApi.get<ApiResponse<InteractionSummaryDto>>(`/artifacts/${artifactId}/interaction-summary`);
    if (res.code !== 200 || !res.data) {
      throw new Error(res.message || '获取文物交互摘要失败');
    }
    return res.data;
  }

  static async getArtifactLikeSummary(artifactId: string, username: string, snapshots: LikeItem[] = []): Promise<InteractionSummary> {
    const summary = await InteractionApiService.getArtifactInteractionSummary(artifactId);
    let active = summary.isLiked === true;
    if (username && !active) {
      const likes = await InteractionApiService.getLikes(username, snapshots);
      active = likes.some((item: LikeItem) => item.artifactId === artifactId);
    }
    const result: InteractionSummary = {
      active: active,
      count: summary.likeCount || 0
    };
    return result;
  }

  static async getArtifactFavoriteSummary(artifactId: string, username: string, snapshots: FavoriteItem[] = []): Promise<InteractionSummary> {
    const summary = await InteractionApiService.getArtifactInteractionSummary(artifactId);
    let active = summary.isFavorited === true;
    if (username && !active) {
      const favorites = await InteractionApiService.getFavorites(username, snapshots);
      active = favorites.some((item: FavoriteItem) => item.artifactId === artifactId);
    }
    const result: InteractionSummary = {
      active: active,
      count: summary.favoriteCount || 0
    };
    return result;
  }

  static async likeArtifact(artifactId: string): Promise<InteractionSummary> {
    const body: EmptyBody = {};
    const res = await HttpApi.post<ApiResponse<ToggleLikeDto>>(`/artifacts/${artifactId}/likes`, body);
    if (res.code !== 200 || !res.data) {
      throw new Error(res.message || '点赞失败');
    }
    const result: InteractionSummary = {
      active: res.data.isLiked === true,
      count: res.data.likeCount || 0
    };
    return result;
  }

  static async unlikeArtifact(artifactId: string): Promise<InteractionSummary> {
    const res = await HttpApi.delete<ApiResponse<ToggleLikeDto>>(`/artifacts/${artifactId}/likes`);
    if (res.code !== 200 || !res.data) {
      throw new Error(res.message || '取消点赞失败');
    }
    const result: InteractionSummary = {
      active: res.data.isLiked === true,
      count: res.data.likeCount || 0
    };
    return result;
  }

  static async getLikes(username: string, snapshots: LikeItem[] = []): Promise<LikeItem[]> {
    const query = InteractionApiService.buildPageQuery();
    const res = await HttpApi.get<ApiResponse<Object>>(`/users/${username}/likes`, query);
    if (res.code !== 200) {
      throw new Error(res.message || '获取点赞列表失败');
    }
    const items = InteractionApiService.pickItems<LikeRecordDto>(res.data);
    return items.map((item: LikeRecordDto): LikeItem => {
      const artifactId = item.artifactId || item.objectId || '';
      const snapshot = snapshots.find((local: LikeItem) => local.artifactId === artifactId);
      return InteractionApiService.mergeLikeRecord(item, snapshot);
    });
  }

  static async getCommentsForArtifact(artifactId: string): Promise<CommentItem[]> {
    const query = InteractionApiService.buildPageQuery();
    const res = await HttpApi.get<ApiResponse<Object>>(`/artifacts/${artifactId}/comments`, query);
    if (res.code !== 200) {
      throw new Error(res.message || '获取评论列表失败');
    }
    const items = InteractionApiService.pickItems<CommentDto>(res.data);
    return InteractionApiService.flattenComments(items, artifactId);
  }

  static async addComment(artifactId: string, content: string, parentId: string = ''): Promise<CommentPostResultDto> {
    const body: CommentCreateBody = {
      content: content,
      parentId: parentId ? parentId : null
    };
    const res = await HttpApi.post<ApiResponse<CommentPostResultDto>>(`/artifacts/${artifactId}/comments`, body);
    if (res.code !== 200 || !res.data) {
      throw new Error(res.message || '评论提交失败');
    }
    return res.data;
  }

  static async likeComment(commentId: string): Promise<InteractionSummary> {
    const body: EmptyBody = {};
    const res = await HttpApi.post<ApiResponse<ToggleLikeDto>>(`/comments/${commentId}/likes`, body);
    if (res.code !== 200 || !res.data) {
      throw new Error(res.message || '评论点赞失败');
    }
    const result: InteractionSummary = {
      active: res.data.isLiked === true,
      count: res.data.likeCount || 0
    };
    return result;
  }

  static async getUserComments(username: string): Promise<CommentItem[]> {
    const query = InteractionApiService.buildPageQuery();
    const res = await HttpApi.get<ApiResponse<Object>>(`/users/${username}/comments`, query);
    if (res.code !== 200) {
      throw new Error(res.message || '获取我的评论失败');
    }
    const items = InteractionApiService.pickItems<CommentDto>(res.data);
    return items.map((item: CommentDto): CommentItem => {
      const comment: CommentItem = {
        id: item.objectId || '',
        artifactId: item.artifactId || '',
        artifactTitle: item.artifactTitle || '',
        username: item.userName || username,
        content: item.content || '',
        createdAt: item.createTime || item.createdAt || new Date().toISOString(),
        status: InteractionApiService.mapReviewStatus(item.status),
        parentId: item.parentId,
        replyTo: item.replyTo,
        likeCount: item.likeCount || 0,
        likedByCurrentUser: item.likedByCurrentUser === true
      };
      return comment;
    });
  }

  static async recordHistory(username: string, artifactId: string): Promise<void> {
    const body: HistoryCreateBody = {
      artifactId: artifactId
    };
    const res = await HttpApi.post<ApiResponse<Object>>(`/users/${username}/history`, body);
    if (res.code !== 200) {
      throw new Error(res.message || '记录浏览历史失败');
    }
  }

  static async getHistory(username: string, snapshots: HistoryItem[] = []): Promise<HistoryItem[]> {
    const query = InteractionApiService.buildPageQuery();
    const res = await HttpApi.get<ApiResponse<Object>>(`/users/${username}/history`, query);
    if (res.code !== 200) {
      throw new Error(res.message || '获取浏览记录失败');
    }
    const items = InteractionApiService.pickItems<HistoryRecordDto>(res.data);
    return items.map((item: HistoryRecordDto): HistoryItem => {
      const artifactId = item.artifactId || item.objectId || '';
      const snapshot = snapshots.find((local: HistoryItem) => local.artifactId === artifactId);
      return InteractionApiService.mergeHistoryRecord(item, snapshot);
    });
  }

  static async getPrivacy(username: string): Promise<PrivacySettings> {
    const res = await HttpApi.get<ApiResponse<PrivacyDto>>(`/users/${username}/privacy`);
    if (res.code !== 200 || !res.data) {
      throw new Error(res.message || '获取隐私设置失败');
    }
    const result: PrivacySettings = {
      showFavorites: res.data.favoritesVisible !== false,
      showLikes: res.data.likesVisible !== false,
      showComments: res.data.commentsVisible !== false,
      showPhotos: res.data.uploadsVisible !== false
    };
    return result;
  }

  static async savePrivacy(username: string, privacy: PrivacySettings): Promise<PrivacySettings> {
    const body: PrivacySaveBody = {
      favoritesVisible: privacy.showFavorites,
      likesVisible: privacy.showLikes,
      commentsVisible: privacy.showComments,
      uploadsVisible: privacy.showPhotos
    };
    const res = await HttpApi.put<ApiResponse<PrivacyDto>>(`/users/${username}/privacy`, body);
    if (res.code !== 200 || !res.data) {
      throw new Error(res.message || '保存隐私设置失败');
    }
    const result: PrivacySettings = {
      showFavorites: res.data.favoritesVisible !== false,
      showLikes: res.data.likesVisible !== false,
      showComments: res.data.commentsVisible !== false,
      showPhotos: res.data.uploadsVisible !== false
    };
    return result;
  }
}

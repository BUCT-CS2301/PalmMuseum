// common/services/PublicHomepageService.ets
import {
  CommentItem,
  FavoriteItem,
  LikeItem,
  PrivacySettings,
  UploadedPhotoItem
} from '../models/InteractionModels';
import { HttpApi } from '../network/HttpApi';
import { interactionStore } from '../store/InteractionStore';
import { PrivacyService } from './PrivacyService';

interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

interface PublicProfileResponseData {
  objectId?: string;
  username?: string;
  nickname?: string;
  avatar?: string;
  bio?: string;
}

type PublicProbeData = Object | Object[] | null;

export interface PublicUserProfile {
  userId: string;
  username: string;
  nickname: string;
  avatar: string;
  bio: string;
}

export interface VisibleConfig {
  favorites: boolean;
  likes: boolean;
  comments: boolean;
  uploads: boolean;
}

export interface PublicDataAvailability {
  favorites: boolean;
  likes: boolean;
  comments: boolean;
  uploads: boolean;
}

interface FavoriteSectionLoadResult {
  items: FavoriteItem[];
  available: boolean;
}

interface LikeSectionLoadResult {
  items: LikeItem[];
  available: boolean;
}

interface CommentSectionLoadResult {
  items: CommentItem[];
  available: boolean;
}

interface UploadSectionLoadResult {
  items: UploadedPhotoItem[];
  available: boolean;
}

export interface PublicHomepageData {
  profile: PublicUserProfile;
  privacy: PrivacySettings;
  visible: VisibleConfig;
  availability: PublicDataAvailability;
  favorites: FavoriteItem[];
  likes: LikeItem[];
  comments: CommentItem[];
  uploads: UploadedPhotoItem[];
}

export class PublicHomepageService {
  private static buildFallbackProfile(username: string, isSelf: boolean): PublicUserProfile {
    return {
      userId: '',
      username: username,
      nickname: username,
      avatar: '',
      bio: isSelf ? '这是我的主页' : '掌上博物馆用户'
    };
  }

  private static async getPublicProfile(username: string, isSelf: boolean): Promise<PublicUserProfile> {
    try {
      const response = await HttpApi.get<ApiResponse<PublicProfileResponseData>>(`/users/${username}/profile`);
      if (response.code === 200 && response.data) {
        return {
          userId: response.data.objectId || '',
          username: response.data.username || username,
          nickname: response.data.nickname || response.data.username || username,
          avatar: response.data.avatar || '',
          bio: response.data.bio || (isSelf ? '这是我的主页' : '掌上博物馆用户')
        };
      }
    } catch (error) {
      console.error(
        `[PublicHomepageService] getPublicProfile failed username=${username} ${JSON.stringify(error)}`
      );
    }

    return PublicHomepageService.buildFallbackProfile(username, isSelf);
  }

  private static isPublicDataDenied(error: Error): boolean {
    const message = error.message || '';
    return message.indexOf('只能查看自己的用户数据') > -1
      || message.indexOf('只能查看自己的上传记录') > -1;
  }

  private static async probePublicSection(url: string, isSelf: boolean): Promise<boolean> {
    if (isSelf) {
      return true;
    }

    try {
      const response = await HttpApi.get<ApiResponse<PublicProbeData>>(url);
      return response.code === 200;
    } catch (error) {
      const err = error as Error;
      if (PublicHomepageService.isPublicDataDenied(err)) {
        return false;
      }

      throw err;
    }
  }

  private static async loadFavorites(
    username: string,
    enabled: boolean,
    isSelf: boolean
  ): Promise<FavoriteSectionLoadResult> {
    if (!enabled) {
      const disabledResult: FavoriteSectionLoadResult = {
        items: [],
        available: false
      };
      return disabledResult;
    }

    const available = await PublicHomepageService.probePublicSection(`/users/${username}/favorites`, isSelf);
    if (!available) {
      const unavailableResult: FavoriteSectionLoadResult = {
        items: [],
        available: false
      };
      return unavailableResult;
    }

    const result: FavoriteSectionLoadResult = {
      items: await interactionStore.getFavorites(username),
      available: true
    };
    return result;
  }

  private static async loadLikes(
    username: string,
    enabled: boolean,
    isSelf: boolean
  ): Promise<LikeSectionLoadResult> {
    if (!enabled) {
      const disabledResult: LikeSectionLoadResult = {
        items: [],
        available: false
      };
      return disabledResult;
    }

    const available = await PublicHomepageService.probePublicSection(`/users/${username}/likes`, isSelf);
    if (!available) {
      const unavailableResult: LikeSectionLoadResult = {
        items: [],
        available: false
      };
      return unavailableResult;
    }

    const result: LikeSectionLoadResult = {
      items: await interactionStore.getLikes(username),
      available: true
    };
    return result;
  }

  private static async loadComments(
    username: string,
    enabled: boolean,
    isSelf: boolean
  ): Promise<CommentSectionLoadResult> {
    if (!enabled) {
      const disabledResult: CommentSectionLoadResult = {
        items: [],
        available: false
      };
      return disabledResult;
    }

    const available = await PublicHomepageService.probePublicSection(`/users/${username}/comments`, isSelf);
    if (!available) {
      const unavailableResult: CommentSectionLoadResult = {
        items: [],
        available: false
      };
      return unavailableResult;
    }

    const result: CommentSectionLoadResult = {
      items: await interactionStore.getUserComments(username),
      available: true
    };
    return result;
  }

  private static async loadUploads(
    username: string,
    enabled: boolean,
    isSelf: boolean
  ): Promise<UploadSectionLoadResult> {
    if (!enabled) {
      const disabledResult: UploadSectionLoadResult = {
        items: [],
        available: false
      };
      return disabledResult;
    }

    const available = await PublicHomepageService.probePublicSection(`/users/${username}/uploads`, isSelf);
    if (!available) {
      const unavailableResult: UploadSectionLoadResult = {
        items: [],
        available: false
      };
      return unavailableResult;
    }

    const result: UploadSectionLoadResult = {
      items: await interactionStore.getUploads(username),
      available: true
    };
    return result;
  }

  static async getPublicHomepage(
    username: string,
    currentUsername: string
  ): Promise<PublicHomepageData> {
    if (!username) {
      throw new Error('用户名为空，无法加载主页');
    }

    const isSelf: boolean = username === currentUsername;

    let privacy: PrivacySettings = {
      showFavorites: true,
      showLikes: true,
      showComments: true,
      showPhotos: true
    };

    if (!isSelf) {
      try {
        privacy = await PrivacyService.getUserPrivacy(username);
        console.info(
          `[PublicHomepageService] getUserPrivacy username=${username}, privacy=${JSON.stringify(privacy)}`
        );
      } catch (error) {
        console.error(
          `[PublicHomepageService] getUserPrivacy failed username=${username} ${JSON.stringify(error)}`
        );
        privacy = {
          showFavorites: false,
          showLikes: false,
          showComments: false,
          showPhotos: false
        };
      }
    }

    const visible: VisibleConfig = {
      favorites: isSelf || privacy.showFavorites,
      likes: isSelf || privacy.showLikes,
      comments: isSelf || privacy.showComments,
      uploads: isSelf || privacy.showPhotos
    };

    const favoritesResult = await PublicHomepageService.loadFavorites(username, visible.favorites, isSelf);
    const likesResult = await PublicHomepageService.loadLikes(username, visible.likes, isSelf);
    const commentsResult = await PublicHomepageService.loadComments(username, visible.comments, isSelf);
    const uploadsResult = await PublicHomepageService.loadUploads(username, visible.uploads, isSelf);

    const availability: PublicDataAvailability = {
      favorites: favoritesResult.available,
      likes: likesResult.available,
      comments: commentsResult.available,
      uploads: uploadsResult.available
    };

    const result: PublicHomepageData = {
      profile: await PublicHomepageService.getPublicProfile(username, isSelf),
      privacy: privacy,
      visible: visible,
      availability: availability,
      favorites: favoritesResult.items,
      likes: likesResult.items,
      comments: commentsResult.items,
      uploads: uploadsResult.items
    };
    return result;
  }
}

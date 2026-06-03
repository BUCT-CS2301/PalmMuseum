// common/services/PublicHomepageService.ets
import {
  CommentItem,
  FavoriteItem,
  LikeItem,
  PrivacySettings,
  UploadedPhotoItem
} from '../models/InteractionModels';
import { interactionStore } from '../store/InteractionStore';
import { PrivacyService } from './PrivacyService';

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

export interface PublicHomepageData {
  profile: PublicUserProfile;
  privacy: PrivacySettings;
  visible: VisibleConfig;
  favorites: FavoriteItem[];
  likes: LikeItem[];
  comments: CommentItem[];
  uploads: UploadedPhotoItem[];
}

export class PublicHomepageService {
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

    if (isSelf) {
      // 自己查看自己主页，不受隐私限制。
      privacy = {
        showFavorites: true,
        showLikes: true,
        showComments: true,
        showPhotos: true
      };
    } else {
      try {
        // 关键修复：
        // 他人主页的可见性必须读取后端真实隐私设置，
        // 不能再用 interactionStore.getPrivacy(username) 的本地模拟数据。
        privacy = await PrivacyService.getUserPrivacy(username);

        console.info(
          `[PublicHomepageService] 读取后端隐私设置 username=${username}, privacy=${JSON.stringify(privacy)}`
        );
      } catch (error) {
        console.error(
          `[PublicHomepageService] 读取后端隐私设置失败 username=${username}, error=${JSON.stringify(error)}`
        );

        // 读取失败时为了保护隐私，默认全部不可见。
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

    const favorites: FavoriteItem[] = visible.favorites
      ? await interactionStore.getFavorites(username)
      : [];

    const likes: LikeItem[] = visible.likes
      ? await interactionStore.getLikes(username)
      : [];

    const comments: CommentItem[] = visible.comments
      ? await interactionStore.getUserComments(username)
      : [];

    const uploads: UploadedPhotoItem[] = visible.uploads
      ? await interactionStore.getUploads(username)
      : [];

    return {
      profile: {
        userId: '',
        username: username,
        nickname: username,
        avatar: '',
        bio: isSelf ? '这是我的主页' : '掌上博物馆用户'
      },
      privacy: privacy,
      visible: visible,
      favorites: favorites,
      likes: likes,
      comments: comments,
      uploads: uploads
    };
  }
}
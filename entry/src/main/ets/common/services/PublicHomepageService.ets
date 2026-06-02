import {
  CommentItem,
  FavoriteItem,
  LikeItem,
  PrivacySettings,
  UploadedPhotoItem
} from '../models/InteractionModels';
import { interactionStore } from '../store/InteractionStore';

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

    const privacy: PrivacySettings = isSelf
      ? {
        showFavorites: true,
        showLikes: true,
        showComments: true,
        showPhotos: true
      }
      : await interactionStore.getPrivacy(username);

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
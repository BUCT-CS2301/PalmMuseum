// common/services/PublicHomepageService.ets
import {
  CommentItem,
  FavoriteItem,
  LikeItem,
  PrivacySettings,
  ReviewStatus,
  UploadedPhotoItem
} from '../models/InteractionModels';
import { InteractionService } from './InteractionService';
import { PrivacyService } from './PrivacyService';
import { UserProfile, UserService } from './UserService';
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
  private static buildAliasKeys(items: string[]): string[] {
    const keys: string[] = [];
    items.forEach((item: string) => {
      const trimmed = item ? item.trim() : '';
      if (trimmed && keys.indexOf(trimmed) === -1) {
        keys.push(trimmed);
      }
    });
    return keys;
  }

  private static hasAlias(aliases: string[], target: string): boolean {
    if (!target) {
      return false;
    }
    return aliases.indexOf(target.trim()) > -1;
  }

  private static buildDefaultProfile(
    requestedUsername: string,
    isSelf: boolean
  ): PublicUserProfile {
    return {
      userId: '',
      username: requestedUsername,
      nickname: requestedUsername,
      avatar: '',
      bio: isSelf ? 'My homepage' : 'PalmMuseum user'
    };
  }

  static async getPublicHomepage(
    username: string,
    currentUsername: string
  ): Promise<PublicHomepageData> {
    const requestedUsername: string = username ? username.trim() : '';
    const activeUsername: string = currentUsername ? currentUsername.trim() : '';
    if (!requestedUsername) {
      throw new Error('Empty username');
    }

    let profile: PublicUserProfile = PublicHomepageService.buildDefaultProfile(
      requestedUsername,
      requestedUsername === activeUsername
    );

    try {
      const resolvedProfile: UserProfile = await UserService.getProfileByUsername(requestedUsername);
      profile = {
        userId: resolvedProfile.objectId || '',
        username: resolvedProfile.username || requestedUsername,
        nickname: resolvedProfile.nickname || resolvedProfile.username || requestedUsername,
        avatar: resolvedProfile.avatar || '',
        bio: resolvedProfile.bio || profile.bio
      };
    } catch (error) {
      console.error(
        `[PublicHomepageService] load profile failed username=${requestedUsername}, error=${JSON.stringify(error)}`
      );
    }

    const aliasKeys = PublicHomepageService.buildAliasKeys([
      requestedUsername,
      profile.username,
      profile.nickname
    ]);
    const resolvedUsername: string = profile.username || requestedUsername;
    const isSelf: boolean = PublicHomepageService.hasAlias(aliasKeys, activeUsername);

    let privacy: PrivacySettings = {
      showFavorites: true,
      showLikes: true,
      showComments: true,
      showPhotos: true
    };

    if (!isSelf) {
      try {
        privacy = await PrivacyService.getUserPrivacy(resolvedUsername);
        console.info(
          `[PublicHomepageService] load privacy success username=${resolvedUsername}, privacy=${JSON.stringify(privacy)}`
        );
      } catch (error) {
        console.error(
          `[PublicHomepageService] load privacy failed username=${resolvedUsername}, error=${JSON.stringify(error)}`
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

    let favorites: FavoriteItem[] = [];
    if (visible.favorites) {
      favorites = await InteractionService.getFavorites(resolvedUsername);
      if (!isSelf && favorites.length === 0) {
        favorites = await interactionStore.getPublicFavoritesByAliases(aliasKeys);
      }
    }

    let likes: LikeItem[] = [];
    if (visible.likes) {
      likes = await InteractionService.getLikes(resolvedUsername);
      if (!isSelf && likes.length === 0) {
        likes = await interactionStore.getPublicLikesByAliases(aliasKeys);
      }
    }

    let comments: CommentItem[] = [];
    if (visible.comments) {
      comments = await InteractionService.getUserComments(resolvedUsername);
      if (!isSelf) {
        comments = comments.filter((item: CommentItem) => item.status === ReviewStatus.Approved);
      }
      if (!isSelf && comments.length === 0) {
        comments = await interactionStore.getPublicCommentsByAliases(aliasKeys);
      }
    }

    let uploads: UploadedPhotoItem[] = [];
    if (visible.uploads) {
      uploads = await InteractionService.getUploads(resolvedUsername);
      if (!isSelf) {
        uploads = uploads.filter((item: UploadedPhotoItem) => item.status === ReviewStatus.Approved);
      }
      if (!isSelf && uploads.length === 0) {
        uploads = await interactionStore.getPublicUploadsByAliases(aliasKeys);
      }
    }

    return {
      profile: profile,
      privacy: privacy,
      visible: visible,
      favorites: favorites,
      likes: likes,
      comments: comments,
      uploads: uploads
    };
  }
}

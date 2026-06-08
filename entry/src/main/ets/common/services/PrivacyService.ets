// common/services/PrivacyService.ets
import { HttpApi } from '../network/HttpApi';
import { PrivacySettings } from '../models/InteractionModels';
import { interactionStore } from '../store/InteractionStore';

interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

interface BackendPrivacySettings {
  favoritesVisible: boolean;
  likesVisible: boolean;
  commentsVisible: boolean;
  uploadsVisible: boolean;
}

export class PrivacyService {
  private static getCurrentUsername(): string {
    const username = AppStorage.Get('username') as string;
    return username || '';
  }

  private static toFrontend(data: BackendPrivacySettings): PrivacySettings {
    return {
      showFavorites: data.favoritesVisible,
      showLikes: data.likesVisible,
      showComments: data.commentsVisible,
      showPhotos: data.uploadsVisible
    };
  }

  private static toBackend(privacy: PrivacySettings): BackendPrivacySettings {
    return {
      favoritesVisible: privacy.showFavorites,
      likesVisible: privacy.showLikes,
      commentsVisible: privacy.showComments,
      uploadsVisible: privacy.showPhotos
    };
  }

  static async getMyPrivacy(username?: string): Promise<PrivacySettings> {
    const targetUsername: string = username || PrivacyService.getCurrentUsername();

    if (!targetUsername) {
      throw new Error('请先登录');
    }

    try {
      const res = await HttpApi.get<ApiResponse<BackendPrivacySettings>>(
        `/users/${targetUsername}/privacy`
      );

      if (res.code !== 200 || !res.data) {
        throw new Error(res.message || '获取隐私设置失败');
      }

      const privacy = PrivacyService.toFrontend(res.data);
      await interactionStore.savePrivacy(targetUsername, privacy);
      return privacy;
    } catch (error) {
      console.error(`[PrivacyService] 获取后端隐私设置失败，改用本地兜底 ${JSON.stringify(error)}`);
      return interactionStore.getPrivacy(targetUsername);
    }
  }

  static async updateMyPrivacy(
    username: string,
    privacy: PrivacySettings
  ): Promise<PrivacySettings> {
    const targetUsername: string = username || PrivacyService.getCurrentUsername();

    if (!targetUsername) {
      throw new Error('请先登录');
    }

    try {
      const body: BackendPrivacySettings = PrivacyService.toBackend(privacy);

      const res = await HttpApi.put<ApiResponse<BackendPrivacySettings>>(
        `/users/${targetUsername}/privacy`,
        body
      );

      if (res.code !== 200 || !res.data) {
        throw new Error(res.message || '保存隐私设置失败');
      }

      const saved = PrivacyService.toFrontend(res.data);
      await interactionStore.savePrivacy(targetUsername, saved);
      return saved;
    } catch (error) {
      console.error(`[PrivacyService] 保存后端隐私设置失败，改用本地兜底 ${JSON.stringify(error)}`);
      await interactionStore.savePrivacy(targetUsername, privacy);
      return interactionStore.getPrivacy(targetUsername);
    }
  }

  static async getUserPrivacy(username: string): Promise<PrivacySettings> {
    return PrivacyService.getMyPrivacy(username);
  }
}

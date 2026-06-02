import { PrivacySettings } from '../models/InteractionModels';
import { interactionStore } from '../store/InteractionStore';

export class PrivacyService {
  static async getMyPrivacy(username: string): Promise<PrivacySettings> {
    // 当前 mock 阶段：从本地读取
    return await interactionStore.getPrivacy(username);

    // 后面真实接口阶段，替换成：
    // const res = await HttpApi.get<ApiResponse<PrivacySettings>>('/users/me/privacy');
    // if (res.code !== 200 || !res.data) {
    //   throw new Error(res.message || '获取隐私设置失败');
    // }
    // return res.data;
  }

  static async updateMyPrivacy(username: string, privacy: PrivacySettings): Promise<PrivacySettings> {
    // 当前 mock 阶段：保存到本地
    await interactionStore.savePrivacy(username, privacy);
    return privacy;

    // 后面真实接口阶段，替换成：
    // const res = await HttpApi.put<ApiResponse<PrivacySettings>>('/users/me/privacy', privacy);
    // if (res.code !== 200 || !res.data) {
    //   throw new Error(res.message || '保存隐私设置失败');
    // }
    // return res.data;
  }
}
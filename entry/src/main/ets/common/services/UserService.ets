// common/services/UserService.ets
import common from '@ohos.app.ability.common';
import { HttpApi } from '../network/HttpApi';

export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

export type RegisterType = 'phone' | 'email';

export interface LoginResult {
  success: boolean;
  message?: string;
  username?: string;
  userId?: string;
  accessToken?: string;
  refreshToken?: string;
}

export interface RegisterResult {
  success: boolean;
  message?: string;
}

export interface ChangePasswordResult {
  success: boolean;
  message?: string;
}

export interface UserProfile {
  objectId?: string;
  username: string;
  nickname?: string;
  avatar: string;
  bio: string;
  phone?: string;
  email?: string;
  roles?: string[];
  permissions?: string[];
}

interface LoginRequestBody {
  username: string;
  password: string;
}

interface LoginResponseData {
  expiresIn: number;
  accessToken: string;
  refreshToken: string;
  user?: BackendUserData;
}

interface RegisterRequestBody {
  username: string;
  password: string;
  nickname?: string;
  phone?: string;
  email?: string;
}

interface RegisterResponseData {
  objectId?: string;
  username?: string;
  nickname?: string;
  phone?: string;
  email?: string;
  avatar?: string;
  bio?: string;
  createTime?: string;
}

interface BackendUserData {
  objectId?: string;
  username?: string;
  nickname?: string;
  avatar?: string;
  bio?: string;
  phone?: string;
  email?: string;
  roles?: string[];
  permissions?: string[];
}

interface UpdateProfileRequestBody {
  nickname?: string;
  bio?: string;
  phone?: string;
  email?: string;
}

interface ChangePasswordRequestBody {
  oldPassword: string;
  newPassword: string;
}

interface HuaweiLoginRequestBody {
  openId: string;
  unionId?: string;
  nickname?: string;
  avatar?: string;
  email?: string;
}

interface HuaweiLoginResponseData {
  expiresIn: number;
  accessToken: string;
  refreshToken: string;
  user?: BackendUserData;
}

interface AvatarBase64RequestBody {
  fileName: string;
  contentType: string;
  base64: string;
}

interface AvatarUploadData {
  avatar: string;
}

export class UserService {
  private static clearProfileStorage(): void {
    AppStorage.SetOrCreate('userId', '');
    AppStorage.SetOrCreate('username', '');
    AppStorage.SetOrCreate('nickname', '');
    AppStorage.SetOrCreate('avatar', '');
    AppStorage.SetOrCreate('bio', '');
    AppStorage.SetOrCreate('phone', '');
    AppStorage.SetOrCreate('email', '');
  }

  private static saveProfileToStorage(profile: UserProfile): void {
    AppStorage.SetOrCreate('userId', profile.objectId || '');
    AppStorage.SetOrCreate('username', profile.username || '');
    AppStorage.SetOrCreate('nickname', profile.nickname || profile.username || '');
    AppStorage.SetOrCreate('avatar', profile.avatar || '');
    AppStorage.SetOrCreate('bio', profile.bio || '');
    AppStorage.SetOrCreate('phone', profile.phone || '');
    AppStorage.SetOrCreate('email', profile.email || '');
  }

  static async login(username: string, password: string): Promise<LoginResult> {
    try {
      const body: LoginRequestBody = {
        username: username.trim(),
        password: password
      };

      const res = await HttpApi.post<ApiResponse<LoginResponseData>>(
        '/auth/login',
        body,
        { skipAuth: true }
      );

      if (res.code !== 200 || !res.data || !res.data.accessToken) {
        return {
          success: false,
          message: res.message || '登录失败'
        };
      }

      AppStorage.SetOrCreate('token', res.data.accessToken);
      AppStorage.SetOrCreate('refreshToken', res.data.refreshToken || '');
      AppStorage.SetOrCreate('isLogin', true);

      if (res.data.user) {
        const userProfile: UserProfile = UserService.toUserProfile(res.data.user, username.trim());
        UserService.saveProfileToStorage(userProfile);

        return {
          success: true,
          message: '登录成功',
          username: userProfile.username,
          userId: userProfile.objectId || '',
          accessToken: res.data.accessToken,
          refreshToken: res.data.refreshToken
        };
      }

      try {
        const profile: UserProfile = await UserService.getProfile();

        UserService.saveProfileToStorage(profile);

        return {
          success: true,
          message: '登录成功',
          username: profile.username || username.trim(),
          userId: profile.objectId || '',
          accessToken: res.data.accessToken,
          refreshToken: res.data.refreshToken
        };
      } catch (e) {
        UserService.clearProfileStorage();
        AppStorage.SetOrCreate('username', username.trim());
        AppStorage.SetOrCreate('nickname', username.trim());

        return {
          success: true,
          message: '登录成功',
          username: username.trim(),
          accessToken: res.data.accessToken,
          refreshToken: res.data.refreshToken
        };
      }
    } catch (e) {
      const error = e as Error;
      return {
        success: false,
        message: error.message || '登录失败'
      };
    }
  }

  static async register(
    username: string,
    password: string,
    type: RegisterType,
    value: string
  ): Promise<RegisterResult> {
    try {
      const body: RegisterRequestBody = {
        username: username.trim(),
        password: password,
        nickname: username.trim()
      };

      if (type === 'phone') {
        body.phone = value.trim();
      } else {
        body.email = value.trim();
      }

      const res = await HttpApi.post<ApiResponse<RegisterResponseData>>(
        '/auth/register',
        body,
        { skipAuth: true }
      );

      if (res.code === 200) {
        return {
          success: true,
          message: res.message || '注册成功'
        };
      }

      return {
        success: false,
        message: res.message || '注册失败'
      };
    } catch (e) {
      const error = e as Error;
      return {
        success: false,
        message: error.message || '注册失败'
      };
    }
  }

  static async getProfile(username?: string): Promise<UserProfile> {
    const res = await HttpApi.get<ApiResponse<BackendUserData>>('/auth/current-user');

    if (res.code !== 200 || !res.data) {
      throw new Error(res.message || '获取用户信息失败');
    }

    return UserService.toUserProfile(res.data, username || '');
  }

  static async getProfileByUsername(username: string): Promise<UserProfile> {
    const target: string = username.trim();
    if (!target) {
      throw new Error('用户名不能为空');
    }

    const res = await HttpApi.get<ApiResponse<BackendUserData>>(
      `/users/${encodeURIComponent(target)}/profile`
    );

    if (res.code !== 200 || !res.data) {
      throw new Error(res.message || '获取用户资料失败');
    }

    return UserService.toUserProfile(res.data, target);
  }

  static async updateProfile(profile: UserProfile): Promise<UserProfile> {
    try {
      const body: UpdateProfileRequestBody = {
        nickname: profile.nickname || profile.username,
        bio: profile.bio || '',
        phone: profile.phone || '',
        email: profile.email || ''
      };

      const res = await HttpApi.put<ApiResponse<BackendUserData>>('/users/me/profile', body);

      if (res.code !== 200 || !res.data) {
        throw new Error(res.message || '修改个人资料失败');
      }

      const updatedProfile: UserProfile = UserService.toUserProfile(res.data, profile.username);

      UserService.saveProfileToStorage(updatedProfile);

      return updatedProfile;
    } catch (e) {
      const error = e as Error;
      throw new Error(error.message || '修改个人资料失败');
    }
  }

  static async uploadAvatarBase64(
    fileName: string,
    contentType: string,
    base64: string
  ): Promise<string> {
    try {
      const body: AvatarBase64RequestBody = {
        fileName: fileName,
        contentType: contentType,
        base64: base64
      };

      const res = await HttpApi.post<ApiResponse<AvatarUploadData>>(
        '/users/me/avatar-base64',
        body
      );

      if (res.code !== 200 || !res.data || !res.data.avatar) {
        throw new Error(res.message || '头像上传失败');
      }

      AppStorage.SetOrCreate('avatar', res.data.avatar);

      try {
        const profile: UserProfile = await UserService.getProfile();
        UserService.saveProfileToStorage(profile);
        return profile.avatar || res.data.avatar;
      } catch (e) {
        return res.data.avatar;
      }
    } catch (e) {
      const error = e as Error;
      throw new Error(error.message || '头像上传失败');
    }
  }

  static async uploadAvatar(
    context: common.UIAbilityContext,
    fileUri: string
  ): Promise<string> {
    try {
      if (!fileUri || fileUri.length === 0) {
        throw new Error('请选择头像图片');
      }

      await HttpApi.uploadFile(context, '/users/me/avatar', fileUri, 'file');

      const profile: UserProfile = await UserService.getProfile();

      UserService.saveProfileToStorage(profile);

      return profile.avatar || '';
    } catch (e) {
      const error = e as Error;
      throw new Error(error.message || '头像上传失败');
    }
  }

  static async changePassword(
    oldPassword: string,
    newPassword: string
  ): Promise<ChangePasswordResult> {
    try {
      const body: ChangePasswordRequestBody = {
        oldPassword: oldPassword,
        newPassword: newPassword
      };

      const res = await HttpApi.put<ApiResponse<null>>('/auth/password', body);

      if (res.code === 200) {
        return {
          success: true,
          message: res.message || '密码修改成功'
        };
      }

      return {
        success: false,
        message: res.message || '密码修改失败'
      };
    } catch (e) {
      const error = e as Error;
      return {
        success: false,
        message: error.message || '密码修改失败'
      };
    }
  }

  static async huaweiLogin(): Promise<LoginResult> {
    try {
      const body: HuaweiLoginRequestBody = {
        openId: 'harmony-huawei-openid-test-001',
        unionId: 'harmony-huawei-unionid-test-001',
        nickname: 'Huawei Test User',
        avatar: '',
        email: 'huawei-test@example.com'
      };

      const res = await HttpApi.post<ApiResponse<HuaweiLoginResponseData>>(
        '/auth/huawei-login',
        body,
        { skipAuth: true }
      );

      if (res.code !== 200 || !res.data || !res.data.accessToken) {
        return {
          success: false,
          message: res.message || '华为账号登录失败'
        };
      }

      AppStorage.SetOrCreate('token', res.data.accessToken);
      AppStorage.SetOrCreate('refreshToken', res.data.refreshToken || '');
      AppStorage.SetOrCreate('isLogin', true);

      try {
        const profile: UserProfile = await UserService.getProfile();

        UserService.saveProfileToStorage(profile);

        return {
          success: true,
          message: '华为账号登录成功',
          username: profile.username || '',
          userId: profile.objectId || '',
          accessToken: res.data.accessToken,
          refreshToken: res.data.refreshToken
        };
      } catch (e) {
        if (res.data.user) {
          const userProfile: UserProfile = UserService.toUserProfile(res.data.user, '');
          UserService.saveProfileToStorage(userProfile);

          return {
            success: true,
            message: '华为账号登录成功',
            username: userProfile.username || '',
            userId: userProfile.objectId || '',
            accessToken: res.data.accessToken,
            refreshToken: res.data.refreshToken
          };
        }

        UserService.clearProfileStorage();

        return {
          success: true,
          message: '华为账号登录成功',
          accessToken: res.data.accessToken,
          refreshToken: res.data.refreshToken
        };
      }
    } catch (e) {
      const error = e as Error;
      return {
        success: false,
        message: error.message || '华为账号登录失败'
      };
    }
  }

  private static toUserProfile(data: BackendUserData, fallbackUsername: string): UserProfile {
    return {
      objectId: data.objectId || '',
      username: data.username || fallbackUsername || '',
      nickname: data.nickname || data.username || fallbackUsername || '',
      avatar: data.avatar || '',
      bio: data.bio || '',
      phone: data.phone || '',
      email: data.email || '',
      roles: data.roles || [],
      permissions: data.permissions || []
    };
  }
}

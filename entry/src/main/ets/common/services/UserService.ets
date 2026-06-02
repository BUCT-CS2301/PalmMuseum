// common/services/UserService.ets
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
  user?: CurrentUserData;
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
  createTime?: string;
}

interface CurrentUserData {
  objectId: string;
  username: string;
  nickname?: string;
  avatar?: string;
  bio?: string;
  phone?: string;
  email?: string;
  roles?: string[];
  permissions?: string[];
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
  user?: CurrentUserData;
}

export class UserService {
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
        AppStorage.SetOrCreate('userId', res.data.user.objectId || '');
        AppStorage.SetOrCreate('username', res.data.user.username || username.trim());

        return {
          success: true,
          message: '登录成功',
          username: res.data.user.username || username.trim(),
          userId: res.data.user.objectId || '',
          accessToken: res.data.accessToken,
          refreshToken: res.data.refreshToken
        };
      }

      try {
        const profile: UserProfile = await UserService.getProfile();

        AppStorage.SetOrCreate('userId', profile.objectId || '');
        AppStorage.SetOrCreate('username', profile.username || username.trim());

        return {
          success: true,
          message: '登录成功',
          username: profile.username || username.trim(),
          userId: profile.objectId || '',
          accessToken: res.data.accessToken,
          refreshToken: res.data.refreshToken
        };
      } catch (e) {
        AppStorage.SetOrCreate('username', username.trim());

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
    const res = await HttpApi.get<ApiResponse<CurrentUserData>>('/auth/current-user');

    if (res.code !== 200 || !res.data) {
      throw new Error(res.message || '获取用户信息失败');
    }

    const data = res.data;

    return {
      objectId: data.objectId || '',
      username: data.username || username || '',
      nickname: data.nickname || data.username || '',
      avatar: data.avatar || '',
      bio: data.bio || '',
      phone: data.phone || '',
      email: data.email || '',
      roles: data.roles || [],
      permissions: data.permissions || []
    };
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

      if (res.data.user) {
        AppStorage.SetOrCreate('userId', res.data.user.objectId || '');
        AppStorage.SetOrCreate('username', res.data.user.username || '');

        return {
          success: true,
          message: '华为账号登录成功',
          username: res.data.user.username || '',
          userId: res.data.user.objectId || '',
          accessToken: res.data.accessToken,
          refreshToken: res.data.refreshToken
        };
      }

      const profile: UserProfile = await UserService.getProfile();

      AppStorage.SetOrCreate('userId', profile.objectId || '');
      AppStorage.SetOrCreate('username', profile.username || '');

      return {
        success: true,
        message: '华为账号登录成功',
        username: profile.username || '',
        userId: profile.objectId || '',
        accessToken: res.data.accessToken,
        refreshToken: res.data.refreshToken
      };
    } catch (e) {
      const error = e as Error;
      return {
        success: false,
        message: error.message || '华为账号登录失败'
      };
    }
  }
}
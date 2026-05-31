// common/services/UserService.ets
import { HttpApi } from '../network/HttpApi';

// ---------- 明确所有接口类型 ----------

// 真实接口通用响应
interface ApiResponse<T> {
  code: number;
  message?: string;
  data?: T;
}

// 登录接口返回的 data 结构
interface LoginData {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

interface RegisterRequestBody {
  username: string;
  password: string;
  role: string;
  email?: string;
  phone?: string;
}

// 本地 mock 用户类型
interface MockUser {
  username: string;
  password: string;
  email?: string;
  phone?: string;
}

// 对外暴露的返回类型
export interface LoginResult {
  success: boolean;
  username?: string;
  message?: string;
}

export interface RegisterResult {
  success: boolean;
  message?: string;
}

export interface UserInfo {
  userId: string;
  username: string;
  avatar: string;
  favorites?: Array<object>;
}

export interface UserProfile {
  username: string;
  avatar: string;
  bio: string;
}

interface CurrentUserData {
  objectId: string;
  username: string;
  nickname: string;
  avatar: string;
  roles: string[];
}

export type RegisterType = 'email' | 'phone';

// ---------- 本地 mock 数据 ----------
const USE_MOCK_PROFILE: boolean = true;

const mockUsers: MockUser[] = [
  { username: 'test', password: '123456', email: 'test@example.com' } as MockUser,
  { username: 'admin', password: 'admin', phone: '13800138000' } as MockUser
];

const userProfiles: Map<string, UserProfile> = new Map();

export class UserService {
  // ==================== 登录（真实接口） ====================
  static async login(account: string, password: string): Promise<LoginResult> {
    try {
      const body: Record<string, string> = {
        'username': account,
        'password': password
      };
      const res = await HttpApi.post<ApiResponse<LoginData>>('/auth/login', body);
      if (res.code === 200 && res.data) {
        AppStorage.SetOrCreate('token', res.data.accessToken);
        AppStorage.SetOrCreate('refreshToken', res.data.refreshToken);
        const result: LoginResult = { success: true, username: account };
        return result;
      } else {
        const msg: string = res.message ?? '账号或密码错误';
        const result: LoginResult = { success: false, message: msg };
        return result;
      }
    } catch (e) {
      const errorMsg: string = (e as Error).message || '网络连接失败';
      const result: LoginResult = { success: false, message: errorMsg };
      return result;
    }
  }

  // ==================== 注册 ====================
  static async register(
    username: string,
    password: string,
    type: RegisterType,
    value: string
  ): Promise<RegisterResult> {
    try {
      const roleCode: string = 'USER';

      const body: RegisterRequestBody = {
        username: username,
        password: password,
        role: roleCode
      };

      if (type === 'email') {
        body.email = value;
      } else {
        body.phone = value;
      }

      await HttpApi.post<ApiResponse<Object>>('/users', body);
      const result: RegisterResult = { success: true };
      return result;
    } catch (e) {
      const error = e as Error;
      const result: RegisterResult = { success: false, message: error.message || '注册失败' };
      return result;
    }
  }

  // ==================== 华为登录（暂用 mock） ====================
  static async huaweiLogin(): Promise<LoginResult> {
    await new Promise<void>((resolve) => setTimeout(resolve, 600));
    const huaweiUser: MockUser = {
      username: 'huawei_test',
      password: 'huawei123',
      email: 'huawei@example.com'
    };
    if (!mockUsers.some(u => u.username === huaweiUser.username)) {
      mockUsers.push(huaweiUser);
      userProfiles.set(huaweiUser.username, {
        username: huaweiUser.username,
        avatar: '',
        bio: ''
      });
    }
    const result: LoginResult = { success: true, username: huaweiUser.username };
    return result;
  }

  // ==================== 获取用户资料 ====================
  static async getProfile(username: string): Promise<UserProfile> {
    try {
      const res = await HttpApi.get<ApiResponse<CurrentUserData>>('/auth/current-user');
      if (res.code === 200 && res.data) {
        const data = res.data;
        // 用 nickname 作为 bio（或者你自己加个 bio 字段，文档里没有）
        return {
          username: data.username,
          avatar: data.avatar || '',
          bio: data.nickname || ''   // 暂时用昵称代替简介
        };
      }
    } catch (e) {
      console.error('获取当前用户失败', JSON.stringify(e));
    }
    // 失败时返回空
    return { username: username, avatar: '', bio: '' };
  }

  // ==================== 更新用户资料（暂用 mock） ====================
  static async updateProfile(username: string, avatar: string, bio: string): Promise<void> {
    if (USE_MOCK_PROFILE) {
      await new Promise<void>((resolve) => setTimeout(resolve, 300));
      const profile: UserProfile = { username: username, avatar: avatar, bio: bio };
      userProfiles.set(username, profile);
    } else {
      const body: Record<string, string> = {
        'username': username,
        'avatar': avatar,
        'bio': bio
      };
      await HttpApi.post<ApiResponse<Object>>('/user/profile', body);
    }
  }

  // ==================== 修改密码（暂用 mock） ====================
  static async changePassword(
    username: string,
    oldPassword: string,
    newPassword: string
  ): Promise<boolean> {
    if (USE_MOCK_PROFILE) {
      await new Promise<void>((resolve) => setTimeout(resolve, 500));
      const idx: number = mockUsers.findIndex(u => u.username === username);
      if (idx === -1 || mockUsers[idx].password !== oldPassword) {
        return false;
      }
      mockUsers[idx].password = newPassword;
      return true;
    } else {
      try {
        const body: Record<string, string> = {
          'username': username,
          'oldPassword': oldPassword,
          'newPassword': newPassword
        };
        await HttpApi.post<ApiResponse<Object>>('/user/change-password', body);
        return true;
      } catch (e) {
        console.error('修改密码失败', JSON.stringify(e));
        return false;
      }
    }
  }

  // ==================== 获取用户信息（暂用 mock） ====================
  static async getUserInfo(userId: string): Promise<UserInfo> {
    await new Promise<void>((resolve) => setTimeout(resolve, 500));
    const info: UserInfo = {
      userId: userId,
      username: `用户${userId.slice(-4)}`,
      avatar: '',
      favorites: []
    };
    return info;
  }
}
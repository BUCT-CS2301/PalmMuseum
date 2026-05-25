// common/services/UserService.ets
import { HttpApi } from '../network/HttpApi';

// ---------- 接口定义 ----------
export interface LoginResponse {
  success: boolean;
  username: string;
}

export interface RegisterResponse {
  success: boolean;
  message?: string;
}

export interface UserInfoResponse {
  userId: string;
  username: string;
  avatar: string;
}

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

interface ChangePasswordRequest {
  username: string;
  oldPassword: string;
  newPassword: string;
}

export type RegisterType = 'email' | 'phone';

// 请求体接口
interface LoginRequest {
  username: string;
  password: string;
}

interface RegisterRequest {
  username: string;
  password: string;
  type: RegisterType;
  value: string;
}

interface UpdateProfileRequest {
  username: string;
  avatar: string;
  bio: string;
}

interface HuaweiLoginRequest {
  // 暂时为空对象，后续可添加华为授权码等字段
}

interface MockUser {
  username: string;
  password: string;
  email?: string;
  phone?: string;
}

const USE_MOCK: boolean = true;

const mockUsers: Array<MockUser> = [
  { username: 'test', password: '123456', email: 'test@example.com' },
  { username: 'admin', password: 'admin', phone: '13800138000' }
];

const userProfiles: Map<string, UserProfile> = new Map();

export class UserService {
  // ---------- 登录（用户名/邮箱/手机号 + 密码）----------
  static async login(account: string, password: string): Promise<LoginResult> {
    if (USE_MOCK) {
      await new Promise<void>((resolve) => setTimeout(resolve, 800));
      const user: MockUser | undefined = mockUsers.find(u =>
      (u.username === account || u.email === account || u.phone === account) &&
        u.password === password
      );
      if (user) {
        return { success: true, username: user.username };
      } else {
        return { success: false, message: '账号或密码错误' };
      }
    } else {
      try {
        const loginData: LoginRequest = { username: account, password };
        const response: LoginResponse = await HttpApi.post<LoginResponse>('/login', loginData);
        const result: LoginResult = { success: response.success, username: response.username };
        return result;
      } catch (e) {
        const error = e as Error;
        const result: LoginResult = { success: false, message: error.message || '网络错误' };
        return result;
      }
    }
  }

  // ---------- 注册（手机号或邮箱）----------
  static async register(
    username: string,
    password: string,
    type: RegisterType,
    value: string
  ): Promise<RegisterResult> {
    if (USE_MOCK) {
      await new Promise<void>((resolve) => setTimeout(resolve, 800));
      if (!username || !password || !value) {
        return { success: false, message: '信息填写不完整' };
      }
      const exists = mockUsers.some(u =>
      u.username === username || u.email === value || u.phone === value
      );
      if (exists) {
        return { success: false, message: '用户名或联系方式已被注册' };
      }
      const newUser: MockUser = { username, password };
      if (type === 'email') {
        newUser.email = value;
      } else {
        newUser.phone = value;
      }
      mockUsers.push(newUser);
      userProfiles.set(username, { username, avatar: '', bio: '' });
      return { success: true };
    } else {
      try {
        const registerData: RegisterRequest = { username, password, type, value };
        await HttpApi.post<RegisterResponse>('/register', registerData);
        return { success: true };
      } catch (e) {
        const error = e as Error;
        return { success: false, message: error.message || '注册失败' };
      }
    }
  }

  // ---------- 华为一键登录（mock）----------
  static async huaweiLogin(): Promise<LoginResult> {
    if (USE_MOCK) {
      await new Promise<void>((resolve) => setTimeout(resolve, 600));
      const huaweiUser: MockUser = {
        username: 'huawei_test',
        password: 'huawei123',
        email: 'huawei@example.com'
      };
      if (!mockUsers.some(u => u.username === huaweiUser.username)) {
        mockUsers.push(huaweiUser);
        userProfiles.set(huaweiUser.username, { username: huaweiUser.username, avatar: '', bio: '' });
      }
      return { success: true, username: huaweiUser.username };
    } else {
      try {
        const huaweiLoginData: HuaweiLoginRequest = {};
        const response: LoginResponse = await HttpApi.post<LoginResponse>('/huawei-login', huaweiLoginData);
        return { success: response.success, username: response.username };
      } catch (e) {
        const error = e as Error;
        return { success: false, message: error.message || '华为登录失败' };
      }
    }
  }

  // ---------- 获取用户资料 ----------
  static async getProfile(username: string): Promise<UserProfile> {
    if (USE_MOCK) {
      await new Promise<void>((resolve) => setTimeout(resolve, 300));
      const profile = userProfiles.get(username);
      return profile || { username, avatar: '', bio: '' };
    } else {
      try {
        const response = await HttpApi.get<UserProfile>(`/user/profile/${username}`);
        return response;
      } catch (e) {
        console.error('获取用户资料失败', JSON.stringify(e));
        return { username, avatar: '', bio: '' };
      }
    }
  }

  // ---------- 更新用户资料 ----------
  static async updateProfile(username: string, avatar: string, bio: string): Promise<void> {
    if (USE_MOCK) {
      await new Promise<void>((resolve) => setTimeout(resolve, 300));
      userProfiles.set(username, { username, avatar, bio });
    } else {
      const updateData: UpdateProfileRequest = { username, avatar, bio };
      await HttpApi.post<void>('/user/profile', updateData);
    }
  }

  // ---------- 修改密码 ----------
  static async changePassword(
    username: string,
    oldPassword: string,
    newPassword: string
  ): Promise<boolean> {
    if (USE_MOCK) {
      await new Promise<void>((resolve) => setTimeout(resolve, 500));
      const userIndex = mockUsers.findIndex(u => u.username === username);
      if (userIndex === -1) {
        return false;
      }
      if (mockUsers[userIndex].password !== oldPassword) {
        return false;
      }
      mockUsers[userIndex].password = newPassword;
      return true;
    } else {
      try {
        const changePwdData: ChangePasswordRequest = {
          username,
          oldPassword,
          newPassword
        };
        await HttpApi.post<void>('/user/change-password', changePwdData);
        return true;
      } catch (e) {
        console.error('修改密码失败', JSON.stringify(e));
        return false;
      }
    }
  }

  // ---------- 保留原有的 getUserInfo ----------
  static async getUserInfo(userId: string): Promise<UserInfo> {
    if (USE_MOCK) {
      await new Promise<void>((resolve) => setTimeout(resolve, 500));
      const result: UserInfo = {
        userId: userId,
        username: `用户${userId.slice(-4)}`,
        avatar: '',
        favorites: []
      };
      return result;
    } else {
      try {
        const response: UserInfoResponse = await HttpApi.get<UserInfoResponse>(`/user/${userId}`);
        const result: UserInfo = {
          userId: response.userId,
          username: response.username,
          avatar: response.avatar,
          favorites: []
        };
        return result;
      } catch (e) {
        const error = e as Error;
        const fallback: UserInfo = {
          userId: userId,
          username: '未知用户',
          avatar: '',
          favorites: []
        };
        return fallback;
      }
    }
  }
}
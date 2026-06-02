// common/network/HttpApi.ets
import http from '@ohos.net.http';

const BASE_URL = 'http://60.205.14.101:8080/api/v1';

export interface HttpQueryParam {
  key: string;
  value: string;
}

function buildQueryString(params: HttpQueryParam[]): string {
  let query = '';
  let first = true;
  for (let i = 0; i < params.length; i++) {
    const item = params[i];
    if (first) {
      query += '?';
      first = false;
    } else {
      query += '&';
    }
    query += `${encodeURIComponent(item.key)}=${encodeURIComponent(item.value)}`;
  }
  return query;
}

export class HttpApi {
  // 获取当前存储的 Token
  static getToken(): string {
    return (AppStorage.Get('token') as string) || '';
  }

  static async get<T>(url: string, params?: HttpQueryParam[]): Promise<T> {
    let fullUrl = `${BASE_URL}${url}`;
    if (params) {
      fullUrl += buildQueryString(params);
    }
    const httpRequest = http.createHttp();
    try {
      const token = HttpApi.getToken();
      const headers: Record<string, string> = {};
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }

      const response = await httpRequest.request(fullUrl, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 10000,
        header: headers
      });
      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as T;
      } else if (response.responseCode === 401) {
        // Token 失效，清除登录状态
        AppStorage.SetOrCreate('isLogin', false);
        throw new Error('登录已过期，请重新登录');
      } else {
        throw new Error(`请求失败: ${response.responseCode}`);
      }
    } catch (e) {
      throw new Error(`网络请求异常: ${JSON.stringify(e)}`);
    } finally {
      httpRequest.destroy();
    }
  }

  static async post<T>(url: string, body: object): Promise<T> {
    const httpRequest = http.createHttp();
    try {
      const token = HttpApi.getToken();
      const headers: Record<string, string> = {
        'Content-Type': 'application/json'
      };
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }

      const response = await httpRequest.request(`${BASE_URL}${url}`, {
        method: http.RequestMethod.POST,
        connectTimeout: 10000,
        readTimeout: 10000,
        header: headers,
        extraData: JSON.stringify(body)
      });
      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as T;
      } else if (response.responseCode === 401) {
        AppStorage.SetOrCreate('isLogin', false);
        throw new Error('登录已过期，请重新登录');
      } else {
        throw new Error(`请求失败: ${response.responseCode}`);
      }
    } catch (e) {
      throw new Error(`网络请求异常: ${JSON.stringify(e)}`);
    } finally {
      httpRequest.destroy();
    }
  }

  static async put<T>(url: string, body: object): Promise<T> {
    const httpRequest = http.createHttp();
    try {
      const token = HttpApi.getToken();
      const headers: Record<string, string> = { 'Content-Type': 'application/json' };
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }

      const response = await httpRequest.request(`${BASE_URL}${url}`, {
        method: http.RequestMethod.PUT,
        connectTimeout: 10000,
        readTimeout: 10000,
        header: headers,
        extraData: JSON.stringify(body)
      });

      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as T;
      } else if (response.responseCode === 401) {
        AppStorage.SetOrCreate('isLogin', false);
        throw new Error('登录已过期');
      } else {
        throw new Error(`请求失败: ${response.responseCode}`);
      }
    } finally {
      httpRequest.destroy();
    }
  }

  static async delete<T>(url: string): Promise<T> {
    const httpRequest = http.createHttp();
    try {
      const token = HttpApi.getToken();
      const headers: Record<string, string> = {};
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }

      const response = await httpRequest.request(`${BASE_URL}${url}`, {
        method: http.RequestMethod.DELETE,
        connectTimeout: 10000,
        readTimeout: 10000,
        header: headers
      });

      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as T;
      } else if (response.responseCode === 401) {
        AppStorage.SetOrCreate('isLogin', false);
        throw new Error('登录已过期，请重新登录');
      } else {
        throw new Error(`请求失败: ${response.responseCode}`);
      }
    } catch (e) {
      throw new Error(`网络请求异常: ${JSON.stringify(e)}`);
    } finally {
      httpRequest.destroy();
    }
  }
}

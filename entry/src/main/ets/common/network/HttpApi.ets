// common/network/HttpApi.ets
import http from '@ohos.net.http';

const BASE_URL = 'http://your-backend-server.com/api';

function buildQueryString(params: Record<string, string>): string {
  let query = '';
  let first = true;
  const keys: string[] = Object.keys(params);
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i];
    if (first) {
      query += '?';
      first = false;
    } else {
      query += '&';
    }
    query += `${encodeURIComponent(key)}=${encodeURIComponent(params[key])}`;
  }
  return query;
}

export class HttpApi {
  static async get<T>(url: string, params?: Record<string, string>): Promise<T> {
    let fullUrl = `${BASE_URL}${url}`;
    if (params) {
      fullUrl += buildQueryString(params);
    }
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(fullUrl, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 10000,
        header: { 'Content-Type': 'application/json' }
      });
      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as T;
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
      const response = await httpRequest.request(`${BASE_URL}${url}`, {
        method: http.RequestMethod.POST,
        connectTimeout: 10000,
        readTimeout: 10000,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify(body)
      });
      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as T;
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
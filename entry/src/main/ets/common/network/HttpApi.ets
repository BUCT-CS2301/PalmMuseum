// common/network/HttpApi.ets
import http from '@ohos.net.http';

const BASE_URL: string = 'http://60.205.14.101:8080/api/v1';

export interface RequestOptions {
  skipAuth?: boolean;
}

interface JsonHeaders {
  'Content-Type': string;
  'Accept': string;
  'Authorization'?: string;
}

interface ErrorResponse {
  code?: number;
  message?: string;
  data?: Object | null;
}

export class HttpApi {
  private static getToken(): string {
    const token = AppStorage.Get('token') as string;
    return token || '';
  }

  private static buildJsonHeaders(options?: RequestOptions): JsonHeaders {
    const headers: JsonHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };

    if (!options || !options.skipAuth) {
      const token: string = HttpApi.getToken();
      if (token) {
        headers.Authorization = `Bearer ${token}`;
      }
    }

    return headers;
  }

  private static parseResponse<T>(raw: string): T {
    return JSON.parse(raw) as T;
  }

  private static getErrorMessage(raw: string, statusCode: number): string {
    if (!raw || raw.length === 0) {
      return `请求失败: ${statusCode}`;
    }

    try {
      const errorResp = JSON.parse(raw) as ErrorResponse;
      return errorResp.message || `请求失败: ${statusCode}`;
    } catch (e) {
      return `请求失败: ${statusCode}`;
    }
  }

  private static handleUnauthorized(): void {
    AppStorage.SetOrCreate('isLogin', false);
    AppStorage.SetOrCreate('token', '');
    AppStorage.SetOrCreate('refreshToken', '');
  }

  static async get<T>(url: string, options?: RequestOptions): Promise<T> {
    const httpRequest = http.createHttp();

    try {
      const fullUrl: string = `${BASE_URL}${url}`;
      const headers: JsonHeaders = HttpApi.buildJsonHeaders(options);

      console.info(`[REQ] GET ${fullUrl}`);

      const response = await httpRequest.request(fullUrl, {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 10000,
        header: headers
      });

      const raw: string = response.result as string;
      console.info(`[RESP] GET ${fullUrl} http=${response.responseCode} body=${raw}`);

      if (response.responseCode >= 200 && response.responseCode < 300) {
        return HttpApi.parseResponse<T>(raw);
      }

      if (response.responseCode === 401) {
        HttpApi.handleUnauthorized();
        throw new Error('登录已过期，请重新登录');
      }

      throw new Error(HttpApi.getErrorMessage(raw, response.responseCode));
    } catch (e) {
      const error = e as Error;
      throw new Error(error.message || '网络请求异常');
    } finally {
      httpRequest.destroy();
    }
  }

  static async post<T>(url: string, body: object, options?: RequestOptions): Promise<T> {
    const httpRequest = http.createHttp();

    try {
      const fullUrl: string = `${BASE_URL}${url}`;
      const headers: JsonHeaders = HttpApi.buildJsonHeaders(options);
      const requestBody: string = JSON.stringify(body);

      console.info(`[REQ] POST ${fullUrl} body=${requestBody}`);

      const response = await httpRequest.request(fullUrl, {
        method: http.RequestMethod.POST,
        connectTimeout: 10000,
        readTimeout: 10000,
        header: headers,
        extraData: requestBody
      });

      const raw: string = response.result as string;
      console.info(`[RESP] POST ${fullUrl} http=${response.responseCode} body=${raw}`);

      if (response.responseCode >= 200 && response.responseCode < 300) {
        return HttpApi.parseResponse<T>(raw);
      }

      if (response.responseCode === 401) {
        HttpApi.handleUnauthorized();
        throw new Error('登录已过期，请重新登录');
      }

      throw new Error(HttpApi.getErrorMessage(raw, response.responseCode));
    } catch (e) {
      const error = e as Error;
      throw new Error(error.message || '网络请求异常');
    } finally {
      httpRequest.destroy();
    }
  }

  static async put<T>(url: string, body: object, options?: RequestOptions): Promise<T> {
    const httpRequest = http.createHttp();

    try {
      const fullUrl: string = `${BASE_URL}${url}`;
      const headers: JsonHeaders = HttpApi.buildJsonHeaders(options);
      const requestBody: string = JSON.stringify(body);

      console.info(`[REQ] PUT ${fullUrl} body=${requestBody}`);

      const response = await httpRequest.request(fullUrl, {
        method: http.RequestMethod.PUT,
        connectTimeout: 10000,
        readTimeout: 10000,
        header: headers,
        extraData: requestBody
      });

      const raw: string = response.result as string;
      console.info(`[RESP] PUT ${fullUrl} http=${response.responseCode} body=${raw}`);

      if (response.responseCode >= 200 && response.responseCode < 300) {
        return HttpApi.parseResponse<T>(raw);
      }

      if (response.responseCode === 401) {
        HttpApi.handleUnauthorized();
        throw new Error('登录已过期，请重新登录');
      }

      throw new Error(HttpApi.getErrorMessage(raw, response.responseCode));
    } catch (e) {
      const error = e as Error;
      throw new Error(error.message || '网络请求异常');
    } finally {
      httpRequest.destroy();
    }
  }

  static async delete<T>(url: string, options?: RequestOptions): Promise<T> {
    const httpRequest = http.createHttp();

    try {
      const fullUrl: string = `${BASE_URL}${url}`;
      const headers: JsonHeaders = HttpApi.buildJsonHeaders(options);

      console.info(`[REQ] DELETE ${fullUrl}`);

      const response = await httpRequest.request(fullUrl, {
        method: http.RequestMethod.DELETE,
        connectTimeout: 10000,
        readTimeout: 10000,
        header: headers
      });

      const raw: string = response.result as string;
      console.info(`[RESP] DELETE ${fullUrl} http=${response.responseCode} body=${raw}`);

      if (response.responseCode >= 200 && response.responseCode < 300) {
        return HttpApi.parseResponse<T>(raw);
      }

      if (response.responseCode === 401) {
        HttpApi.handleUnauthorized();
        throw new Error('登录已过期，请重新登录');
      }

      throw new Error(HttpApi.getErrorMessage(raw, response.responseCode));
    } catch (e) {
      const error = e as Error;
      throw new Error(error.message || '网络请求异常');
    } finally {
      httpRequest.destroy();
    }
  }
}
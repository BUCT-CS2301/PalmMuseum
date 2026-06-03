// common/network/HttpApi.ets
import http from '@ohos.net.http';
import request from '@ohos.request';
import common from '@ohos.app.ability.common';

const BASE_URL: string = 'http://60.205.14.101:8080/api/v1';

export interface RequestOptions {
  skipAuth?: boolean;
}

interface JsonHeaders {
  'Content-Type': string;
  'Accept': string;
  'Authorization'?: string;
}

interface UploadHeaders {
  'Authorization'?: string;
}

export interface UploadFormField {
  name: string;
  value: string;
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

  private static buildUploadHeaders(): UploadHeaders {
    const headers: UploadHeaders = {};
    const token: string = HttpApi.getToken();

    if (token) {
      headers.Authorization = `Bearer ${token}`;
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

      if (url.indexOf('avatar-base64') >= 0) {
        console.info(`[REQ] POST ${fullUrl} body=<avatar-base64 omitted>, length=${requestBody.length}`);
      } else {
        console.info(`[REQ] POST ${fullUrl} body=${requestBody}`);
      }

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

  static async uploadFile(
    context: common.UIAbilityContext,
    url: string,
    fileUri: string,
    fieldName: string,
    data: UploadFormField[] = []
  ): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      const fullUrl: string = `${BASE_URL}${url}`;
      const headers: UploadHeaders = HttpApi.buildUploadHeaders();

      if (!headers.Authorization) {
        reject(new Error('请先登录'));
        return;
      }

      if (!fileUri || fileUri.length === 0) {
        reject(new Error('上传文件路径为空'));
        return;
      }

      const fileName: string = HttpApi.getFileNameFromUri(fileUri);
      const fileType: string = HttpApi.getFileTypeFromName(fileName);

      console.info(`[REQ] UPLOAD ${fullUrl}`);
      console.info(`[REQ] UPLOAD fileUri=${fileUri}`);
      console.info(`[REQ] UPLOAD fileName=${fileName}, fileType=${fileType}`);

      const config: request.UploadConfig = {
        url: fullUrl,
        header: headers,
        method: 'POST',
        files: [
          {
            filename: fileName,
            name: fieldName,
            uri: fileUri,
            type: fileType
          }
        ],
        data: data
      };

      request.uploadFile(context, config)
        .then((uploadTask: request.UploadTask) => {
          uploadTask.on('complete', (taskStates: Array<request.TaskState>) => {
            console.info(`[RESP] UPLOAD ${fullUrl} complete=${JSON.stringify(taskStates)}`);

            if (taskStates && taskStates.length > 0) {
              const state: request.TaskState = taskStates[0];

              if (state.responseCode >= 200 && state.responseCode < 300) {
                resolve();
                return;
              }

              if (state.responseCode === 401) {
                HttpApi.handleUnauthorized();
                reject(new Error('登录已过期，请重新登录'));
                return;
              }

              reject(new Error(`上传失败：code=${state.responseCode}, message=${state.message || '无错误信息'}`));
              return;
            }

            reject(new Error('上传失败：无任务状态'));
          });

          uploadTask.on('fail', (taskStates: Array<request.TaskState>) => {
            console.error(`[RESP] UPLOAD ${fullUrl} fail=${JSON.stringify(taskStates)}`);

            if (taskStates && taskStates.length > 0) {
              const state: request.TaskState = taskStates[0];
              reject(new Error(`上传失败：code=${state.responseCode}, message=${state.message || '无错误信息'}`));
              return;
            }

            reject(new Error('上传失败：无任务状态'));
          });
        })
        .catch((error: Error) => {
          console.error(`[HttpApi] uploadFile异常 ${JSON.stringify(error)}`);
          reject(new Error(error.message || '上传失败'));
        });
    });
  }

  private static getFileNameFromUri(fileUri: string): string {
    if (!fileUri || fileUri.length === 0) {
      return `avatar_${new Date().getTime()}.jpg`;
    }

    const parts: string[] = fileUri.split('/');
    const last: string = parts.length > 0 ? parts[parts.length - 1] : '';

    if (last && last.indexOf('.') >= 0) {
      return last;
    }

    return `avatar_${new Date().getTime()}.jpg`;
  }

  private static getFileTypeFromName(fileName: string): string {
    const lowerName: string = fileName.toLowerCase();

    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }

    if (lowerName.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (lowerName.endsWith('.jpg')) {
      return 'image/jpeg';
    }

    return 'image/jpeg';
  }
}

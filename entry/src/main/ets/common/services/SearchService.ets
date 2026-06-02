import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { SEARCH_IMAGE_URL, DEFAULT_TOP_K, DEFAULT_THRESHOLD } from '../Constants';
import { SearchResponse } from '../models/SearchModels';

async function readFileToArrayBuffer(uri: string): Promise<ArrayBuffer> {
  let file: fs.File | null = null;
  try {
    file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    const stat = fs.statSync(uri);
    const buffer = new ArrayBuffer(stat.size);
    const readLen = fs.readSync(file.fd, buffer);
    if (readLen !== stat.size) {
      throw new Error('文件读取长度不匹配');
    }
    return buffer;
  } finally {
    if (file) {
      fs.closeSync(file.fd);
    }
  }
}

export class SearchService {
  static async searchByImage(
    fileUri: string,
    fileName: string,
    top_k: number = DEFAULT_TOP_K,
    threshold: number = DEFAULT_THRESHOLD
  ): Promise<SearchResponse> {
    // 1. 读取文件
    const fileData = await readFileToArrayBuffer(fileUri);

    // 2. 构建 multipart 数据
    const boundary = '----WebKitFormBoundary' + Math.random().toString(36).substring(2);
    const CRLF = '\r\n';

    let preamble = `--${boundary}${CRLF}`;
    preamble += `Content-Disposition: form-data; name="file"; filename="${fileName}"${CRLF}`;
    preamble += `Content-Type: image/jpg\r\n\r\n`;;

    const epilogue = `${CRLF}--${boundary}--${CRLF}`;

    const encoder = new util.TextEncoder();
    const preambleBuf = encoder.encodeInto(preamble);
    const epilogueBuf = encoder.encodeInto(epilogue);
    const fileBuf = new Uint8Array(fileData);

    const totalLength = preambleBuf.byteLength + fileBuf.byteLength + epilogueBuf.byteLength;
    const resultBuffer = new Uint8Array(totalLength);
    resultBuffer.set(preambleBuf, 0);
    resultBuffer.set(fileBuf, preambleBuf.byteLength);
    resultBuffer.set(epilogueBuf, preambleBuf.byteLength + fileBuf.byteLength);

    const contentType = `multipart/form-data; boundary=${boundary}`;
    const bodyBuffer = resultBuffer.buffer;

    // 3. 发起请求
    const httpRequest = http.createHttp();
    const url = `${SEARCH_IMAGE_URL}?top_k=${top_k}&threshold=${threshold}`;

    const headers: Record<string, string> = {
      'Content-Type': contentType
    };
    const requestOption: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: bodyBuffer,
      connectTimeout: 60000,
      readTimeout: 60000,
    };

    try {
      const response = await httpRequest.request(url, requestOption);
      if (response.responseCode === 200) {
        const result: SearchResponse = JSON.parse(response.result as string);
        if (result.code === 200) {
          return result;
        } else {
          throw new Error(result.message || '搜索失败');
        }
      } else {
        throw new Error(`HTTP ${response.responseCode}`);
      }
    } catch (err) {
      console.error('搜索请求失败', JSON.stringify(err));
      throw new Error('网络请求失败，请检查后端服务');
    } finally {
      httpRequest.destroy();
    }
  }
}
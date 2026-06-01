import http from '@ohos.net.http';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';

const QA_CHAT_URL = 'http://60.205.14.101:8000/api/chat';
const QA_CONNECT_TIMEOUT = 10000;
const QA_READ_TIMEOUT = 60000;

export interface QaSource {
  name: string;
  url: string;
}

export interface QaImage {
  url: string;
}

export interface QaChatAnswer {
  answer: string;
  sources: QaSource[];
  images: QaImage[];
}

export interface QaChatCallbacks {
  onAnswerUpdate?: (answer: string) => void;
  onSource?: (source: QaSource) => void;
  onImage?: (image: QaImage) => void;
}

export class QaChatService {
  static async ask(question: string, callbacks?: QaChatCallbacks): Promise<QaChatAnswer> {
    const trimmedQuestion = question.trim();
    if (trimmedQuestion.length === 0) {
      throw new Error('问题不能为空');
    }

    const httpRequest = http.createHttp();
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream'
    };
    const token = (AppStorage.Get('token') as string) || '';
    if (token.length > 0) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      connectTimeout: QA_CONNECT_TIMEOUT,
      readTimeout: QA_READ_TIMEOUT,
      header: headers,
      extraData: JSON.stringify({ question: trimmedQuestion })
    };

    return new Promise<QaChatAnswer>((resolve, reject) => {
      let responseBytes = new Uint8Array(0);
      let processedTextLength = 0;
      let currentEvent = '';
      let settled = false;
      const answer: QaChatAnswer = {
        answer: '',
        sources: [],
        images: []
      };

      const cleanup = () => {
        try {
          httpRequest.off('dataReceive');
          httpRequest.off('dataEnd');
        } catch (error) {
          console.info('[QaChatService] 取消流式监听失败，可忽略：' + JSON.stringify(error));
        }

        try {
          httpRequest.destroy();
        } catch (error) {
          console.info('[QaChatService] 释放HTTP请求失败，可忽略：' + JSON.stringify(error));
        }
      };

      const finishResolve = () => {
        if (settled) {
          return;
        }
        settled = true;
        cleanup();
        if (answer.answer.trim().length === 0) {
          reject(new Error('问答服务没有返回有效回答'));
          return;
        }
        resolve(answer);
      };

      const finishReject = (error: Error) => {
        if (settled) {
          return;
        }
        settled = true;
        cleanup();
        reject(error);
      };

      const handleData = (data: string): string => {
        if (currentEvent === 'llm') {
          answer.answer += data;
          callbacks?.onAnswerUpdate?.(answer.answer);
          return '';
        }

        if (currentEvent === 'source') {
          try {
            const parsed = JSON.parse(data) as Record<string, string>;
            const source: QaSource = {
              name: parsed['name'] || '参考来源',
              url: parsed['url'] || ''
            };
            answer.sources.push(source);
            callbacks?.onSource?.(source);
          } catch (error) {
            console.error('[QaChatService] 解析source事件失败：' + JSON.stringify(error));
          }
          return '';
        }

        if (currentEvent === 'img') {
          try {
            const parsed = JSON.parse(data) as Record<string, string>;
            const image: QaImage = {
              url: parsed['url'] || ''
            };
            if (image.url.length > 0) {
              answer.images.push(image);
              callbacks?.onImage?.(image);
            }
          } catch (error) {
            console.error('[QaChatService] 解析img事件失败：' + JSON.stringify(error));
          }
          return '';
        }

        if (currentEvent === 'done') {
          return '';
        }

        if (currentEvent === 'error') {
          return data || '问答服务异常';
        }

        return '';
      };

      const processLine = (line: string): string => {
        const trimmedLine = line.trim();
        if (trimmedLine.length === 0) {
          return '';
        }

        if (trimmedLine.startsWith('event:')) {
          currentEvent = trimmedLine.substring(6).trim();
          return '';
        }

        if (trimmedLine.startsWith('data:')) {
          const data = trimmedLine.substring(5).replace(/^\s*/, '');
          const errorMessage = handleData(data);
          currentEvent = '';
          return errorMessage;
        }

        return '';
      };

      const processText = (text: string): string => {
        const lines = text.split('\n');
        for (let i = 0; i < lines.length; i++) {
          const errorMessage = processLine(lines[i]);
          if (errorMessage.length > 0) {
            return errorMessage;
          }
        }
        return '';
      };

      const decodeResponse = (): string => {
        return util.TextDecoder.create('utf-8').decodeToString(responseBytes);
      };

      const processAvailableText = (forceAll: boolean): string => {
        const decodedText = decodeResponse();
        let nextText = '';
        if (forceAll) {
          nextText = decodedText.substring(processedTextLength);
          processedTextLength = decodedText.length;
        } else {
          const unprocessedText = decodedText.substring(processedTextLength);
          const lastLineBreak = unprocessedText.lastIndexOf('\n');
          if (lastLineBreak < 0) {
            return '';
          }
          nextText = unprocessedText.substring(0, lastLineBreak + 1);
          processedTextLength += lastLineBreak + 1;
        }
        return processText(nextText);
      };

      httpRequest.on('dataReceive', (data: ArrayBuffer) => {
        if (settled) {
          return;
        }

        responseBytes = QaChatService.appendBytes(responseBytes, new Uint8Array(data));
        const errorMessage = processAvailableText(false);
        if (errorMessage.length > 0) {
          finishReject(new Error(errorMessage));
        }
      });

      httpRequest.on('dataEnd', () => {
        if (settled) {
          return;
        }

        const errorMessage = processAvailableText(true);
        if (errorMessage.length > 0) {
          finishReject(new Error(errorMessage));
          return;
        }
        finishResolve();
      });

      httpRequest.requestInStream(QA_CHAT_URL, options, (err: BusinessError, responseCode: number) => {
        if (settled) {
          return;
        }

        if (err) {
          finishReject(new Error('问答请求异常：' + (err.message || JSON.stringify(err))));
          return;
        }

        if (responseCode < 200 || responseCode >= 300) {
          finishReject(new Error(`问答请求失败：${responseCode}`));
        }
      });
    });
  }

  private static appendBytes(left: Uint8Array, right: Uint8Array): Uint8Array {
    const merged = new Uint8Array(left.length + right.length);
    merged.set(left, 0);
    merged.set(right, left.length);
    return merged;
  }
}

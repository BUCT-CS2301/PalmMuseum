// common/utils/ImageBase64Util.ets
import fs from '@ohos.file.fs';
import util from '@ohos.util';

export interface ImageBase64Data {
  fileName: string;
  contentType: string;
  base64: string;
}

interface ImageTypeInfo {
  suffix: string;
  contentType: string;
}

export class ImageBase64Util {
  static readImageAsBase64(sourcePath: string): ImageBase64Data {
    if (!sourcePath || sourcePath.length === 0) {
      throw new Error('图片路径为空');
    }

    let file: fs.File | null = null;

    try {
      file = fs.openSync(sourcePath, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(sourcePath);
      const fileSize: number = stat.size;

      if (fileSize <= 0) {
        throw new Error('图片文件为空');
      }

      const buffer: ArrayBuffer = new ArrayBuffer(fileSize);
      const readLen: number = fs.readSync(file.fd, buffer);

      if (readLen <= 0) {
        throw new Error('读取图片失败');
      }

      const bytes: Uint8Array = new Uint8Array(buffer, 0, readLen);
      const typeInfo: ImageTypeInfo = ImageBase64Util.detectImageType(bytes);

      const base64Helper = new util.Base64Helper();
      const base64Text: string = base64Helper.encodeToStringSync(bytes);

      return {
        fileName: `avatar_${new Date().getTime()}${typeInfo.suffix}`,
        contentType: typeInfo.contentType,
        base64: base64Text
      };
    } catch (e) {
      const error = e as Error;
      throw new Error(error.message || '图片转码失败');
    } finally {
      if (file !== null) {
        try {
          fs.closeSync(file);
        } catch (e) {
        }
      }
    }
  }

  private static detectImageType(bytes: Uint8Array): ImageTypeInfo {
    if (bytes.length >= 8) {
      // PNG: 89 50 4E 47 0D 0A 1A 0A
      if (
        bytes[0] === 0x89 &&
          bytes[1] === 0x50 &&
          bytes[2] === 0x4E &&
          bytes[3] === 0x47
      ) {
        return {
          suffix: '.png',
          contentType: 'image/png'
        };
      }
    }

    if (bytes.length >= 3) {
      // JPEG: FF D8 FF
      if (
        bytes[0] === 0xFF &&
          bytes[1] === 0xD8 &&
          bytes[2] === 0xFF
      ) {
        return {
          suffix: '.jpg',
          contentType: 'image/jpeg'
        };
      }
    }

    if (bytes.length >= 12) {
      // WEBP: RIFF....WEBP
      if (
        bytes[0] === 0x52 &&
          bytes[1] === 0x49 &&
          bytes[2] === 0x46 &&
          bytes[3] === 0x46 &&
          bytes[8] === 0x57 &&
          bytes[9] === 0x45 &&
          bytes[10] === 0x42 &&
          bytes[11] === 0x50
      ) {
        return {
          suffix: '.webp',
          contentType: 'image/webp'
        };
      }
    }

    return {
      suffix: '.jpg',
      contentType: 'image/jpeg'
    };
  }
}
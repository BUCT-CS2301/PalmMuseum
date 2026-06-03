// common/utils/FileCacheUtil.ets
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';

export class FileCacheUtil {
  /**
   * 把相册选择器返回的图片 URI 复制到 App 自己的 cache 目录。
   * 返回真实 cachePath，用于 fs.openSync 读取 base64。
   *
   * 注意：
   * 这里返回的是 /data/storage/.../cache/avatar_xxx.jpg
   * 不是 file://...
   * 也不是 internal://cache/...
   */
  static copyImageToCachePath(context: common.UIAbilityContext, sourceUri: string): string {
    if (!sourceUri || sourceUri.length === 0) {
      throw new Error('图片路径为空');
    }

    const fileName: string = FileCacheUtil.buildCacheFileName(sourceUri);
    const cachePath: string = `${context.cacheDir}/${fileName}`;

    console.info(`[FileCacheUtil] sourceUri=${sourceUri}`);
    console.info(`[FileCacheUtil] cachePath=${cachePath}`);

    try {
      fs.unlinkSync(cachePath);
    } catch (e) {
      // 文件不存在时忽略
    }

    let srcFile: fs.File | null = null;
    let destFile: fs.File | null = null;

    try {
      srcFile = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY);
      destFile = fs.openSync(cachePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);

      const bufferSize: number = 1024 * 1024;
      const buffer: ArrayBuffer = new ArrayBuffer(bufferSize);

      while (true) {
        const readLen: number = fs.readSync(srcFile.fd, buffer);

        if (readLen <= 0) {
          break;
        }

        fs.writeSync(destFile.fd, buffer, {
          length: readLen
        });
      }
    } catch (e) {
      const error = e as Error;
      console.error(`[FileCacheUtil] 复制图片失败 ${JSON.stringify(error)}`);
      throw new Error(error.message || '复制图片失败');
    } finally {
      if (srcFile !== null) {
        try {
          fs.closeSync(srcFile);
        } catch (e) {
        }
      }

      if (destFile !== null) {
        try {
          fs.closeSync(destFile);
        } catch (e) {
        }
      }
    }

    console.info(`[FileCacheUtil] 图片复制完成 cachePath=${cachePath}`);

    return cachePath;
  }

  /**
   * 保留旧方法，避免其他地方如果还引用 copyImageToCache 不会直接编译崩。
   * 但头像 base64 上传现在不要用这个方法。
   */
  static copyImageToCache(context: common.UIAbilityContext, sourceUri: string): string {
    const cachePath: string = FileCacheUtil.copyImageToCachePath(context, sourceUri);
    const fileName: string = FileCacheUtil.getFileNameFromPath(cachePath);
    return `internal://cache/${fileName}`;
  }

  private static buildCacheFileName(sourceUri: string): string {
    const lowerUri: string = sourceUri.toLowerCase();

    let suffix: string = '.jpg';

    if (lowerUri.indexOf('.png') >= 0) {
      suffix = '.png';
    } else if (lowerUri.indexOf('.webp') >= 0) {
      suffix = '.webp';
    } else if (lowerUri.indexOf('.jpeg') >= 0) {
      suffix = '.jpeg';
    } else if (lowerUri.indexOf('.jpg') >= 0) {
      suffix = '.jpg';
    }

    return `avatar_${new Date().getTime()}${suffix}`;
  }

  private static getFileNameFromPath(path: string): string {
    if (!path || path.length === 0) {
      return `avatar_${new Date().getTime()}.jpg`;
    }

    const parts: string[] = path.split('/');
    if (parts.length === 0) {
      return `avatar_${new Date().getTime()}.jpg`;
    }

    return parts[parts.length - 1];
  }
}
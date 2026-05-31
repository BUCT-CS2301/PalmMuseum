// common/services/ImageDecoder.ets
//
// 真机图片解码器（设备 API，依赖 @kit.ImageKit）。
// 它是 ImageSearchService 注入的 decode 实现：把一张图解码、缩放到固定小尺寸、读出 RGBA 像素。
// 单测不引用本文件，故所有 @ohos / @kit 依赖都隔离在这里。
//
// 支持三种来源（按 uri 前缀分发）：
//   - rawfile://<名字>   读取打包进 rawfile 的本地图（离线建库用）
//   - http(s)://...      网络图：先下载字节再解码（后端/远程图建库用）
//   - 其它(file://media/、/data/... 等)  相册/拍照拿到的本地 uri，直接解码

import { image } from '@kit.ImageKit';
import http from '@ohos.net.http';
import common from '@ohos.app.ability.common';
import { RAWFILE_SCHEME, DecodedImage, ImageDecoder } from './ImageSearchService';

/** 解码时缩放到的固定边长（与特征算法约定的小尺寸一致） */
const DECODE_SIZE = 32;

/** 下载网络图片的原始字节 */
async function downloadBytes(url: string): Promise<ArrayBuffer> {
  const httpRequest = http.createHttp();
  try {
    const response = await httpRequest.request(url, {
      method: http.RequestMethod.GET,
      connectTimeout: 10000,
      readTimeout: 15000,
      expectDataType: http.HttpDataType.ARRAY_BUFFER
    });
    if (response.responseCode !== 200) {
      throw new Error(`下载图片失败: ${response.responseCode}`);
    }
    return response.result as ArrayBuffer;
  } finally {
    httpRequest.destroy();
  }
}

/** 根据 uri 来源创建 ImageSource */
async function createSource(uri: string, context: common.UIAbilityContext): Promise<image.ImageSource> {
  if (uri.startsWith(RAWFILE_SCHEME)) {
    const name = uri.substring(RAWFILE_SCHEME.length);
    const bytes: Uint8Array = await context.resourceManager.getRawFileContent(name);
    return image.createImageSource(bytes.buffer as ArrayBuffer);
  }
  if (uri.startsWith('http')) {
    const bytes = await downloadBytes(uri);
    return image.createImageSource(bytes);
  }
  // 相册/拍照等本地 uri，直接交给 ImageKit 解码
  return image.createImageSource(uri);
}

/**
 * 创建真机解码器。上层（页面）拿到 UIAbilityContext 后调用本工厂，
 * 把返回的函数作为 decode 注入 ImageSearchService。
 */
export function createDeviceImageDecoder(context: common.UIAbilityContext): ImageDecoder {
  return async (uri: string): Promise<DecodedImage> => {
    const source = await createSource(uri, context);
    // 解码时直接缩放到 32x32，并指定 RGBA_8888，使读出的像素布局为 R,G,B,A
    const pixelMap = await source.createPixelMap({
      desiredSize: { width: DECODE_SIZE, height: DECODE_SIZE },
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    });
    try {
      const info = await pixelMap.getImageInfo();
      const width = info.size.width;
      const height = info.size.height;
      const buffer = new ArrayBuffer(width * height * 4);
      await pixelMap.readPixelsToBuffer(buffer);
      return { data: new Uint8Array(buffer), width, height };
    } finally {
      pixelMap.release();
      source.release();
    }
  };
}

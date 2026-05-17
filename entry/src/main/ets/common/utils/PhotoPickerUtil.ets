import { picker } from '@kit.CoreFileKit';

export async function pickSingleImageUri(): Promise<string> {
  try {
    const options = new picker.PhotoSelectOptions();
    options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const photoPicker = new picker.PhotoViewPicker();
    const result = await photoPicker.select(options);
    if (result && result.photoUris && result.photoUris.length > 0) {
      return result.photoUris[0];
    }
  } catch (error) {
    console.error('选择图片失败: ' + JSON.stringify(error));
  }
  return '';
}
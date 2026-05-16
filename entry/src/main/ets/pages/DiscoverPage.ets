import promptAction from '@ohos.promptAction';
import { MuseumVoiceService } from '../common/voice/MuseumVoiceService';

@Entry
@Component
export struct DiscoverPage {
  @State searchInput: string = '';
  @State voiceText: string = '';

  build() {
    Column() {
      Text('发现')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 40, bottom: 12 })

      Text('语音搜索 / 语音问答')
        .fontSize(18)
        .fontColor('#666666')
        .margin({ bottom: 24 })

      Column() {
        Text('你可以输入：青花、唐三彩、玉琮、青铜、大英博物馆')
          .fontSize(14)
          .fontColor('#888888')
          .margin({ bottom: 16 })

        TextInput({ placeholder: '先用文字模拟语音识别结果，例如：青花' })
          .width('90%')
          .height(48)
          .onChange((value: string) => {
            this.searchInput = value;
          })

        Button('🎙️ 模拟语音搜索')
          .width('90%')
          .height(48)
          .margin({ top: 20 })
          .backgroundColor('#007AFF')
          .onClick(() => {
            if (this.searchInput.trim().length === 0) {
              promptAction.showToast({
                message: '请输入或说出搜索内容'
              });
              return;
            }

            this.voiceText = this.searchInput;
            MuseumVoiceService.handleVoiceSearch(this.voiceText);
          })

        Button('🎧 播放语音提示')
          .width('90%')
          .height(48)
          .margin({ top: 12 })
          .backgroundColor('#28A745')
          .onClick(() => {
            MuseumVoiceService.speak('欢迎使用掌上博物馆语音搜索，请说出你想查找的文物名称、年代、类型或博物馆名称。');
          })

        if (this.voiceText.length > 0) {
          Text('识别结果：' + this.voiceText)
            .fontSize(16)
            .fontColor('#333333')
            .margin({ top: 24 })
        }
      }
      .width('92%')
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(16)

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
    .alignItems(HorizontalAlign.Center)
  }
}
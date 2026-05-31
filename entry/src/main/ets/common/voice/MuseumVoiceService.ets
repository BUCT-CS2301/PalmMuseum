import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { textToSpeech, speechRecognizer } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Artifact, mockArtifacts } from '../models/Artifact';

export class MuseumVoiceService {
  private static ttsEngine: textToSpeech.TextToSpeechEngine | null = null;
  private static creatingEngine: Promise<textToSpeech.TextToSpeechEngine> | null = null;

  private static currentSpeed: number = 1;
  private static currentText: string = '';
  private static paragraphs: string[] = [];
  private static paragraphIndex: number = 0;

  private static asrEngine: speechRecognizer.SpeechRecognitionEngine | null = null;
  private static creatingAsrEngine: Promise<speechRecognizer.SpeechRecognitionEngine> | null = null;
  private static currentAsrSessionId: string = '';

  /**
   * 创建 / 获取 TTS 引擎
   */
  private static async getTtsEngine(): Promise<textToSpeech.TextToSpeechEngine> {
    if (!canIUse('SystemCapability.AI.TextToSpeech')) {
      promptAction.showToast({
        message: '当前设备不支持语音播报'
      });
      throw new Error('当前设备不支持 SystemCapability.AI.TextToSpeech');
    }

    if (MuseumVoiceService.ttsEngine !== null) {
      return MuseumVoiceService.ttsEngine;
    }

    if (MuseumVoiceService.creatingEngine !== null) {
      return MuseumVoiceService.creatingEngine;
    }

    MuseumVoiceService.creatingEngine = new Promise((resolve, reject) => {
      let initParams: textToSpeech.CreateEngineParams = {
        language: 'zh-CN',
        person: 0,
        online: 1,
        extraParams: {
          'style': 'interaction-broadcast',
          'locate': 'CN',
          'name': 'MuseumTtsEngine'
        }
      };

      textToSpeech.createEngine(initParams, (err: BusinessError, engine: textToSpeech.TextToSpeechEngine) => {
        MuseumVoiceService.creatingEngine = null;

        if (err) {
          console.error('[MuseumVoiceService] 创建TTS引擎失败：' + JSON.stringify(err));
          reject(err);
          return;
        }

        MuseumVoiceService.ttsEngine = engine;

        let speakListener: textToSpeech.SpeakListener = {
          onStart(requestId: string, response: textToSpeech.StartResponse) {
            console.info('[MuseumVoiceService] 开始播报：' + requestId + ', ' + JSON.stringify(response));
          },

          onComplete(requestId: string, response: textToSpeech.CompleteResponse) {
            console.info('[MuseumVoiceService] 播报完成：' + requestId + ', ' + JSON.stringify(response));
          },

          onStop(requestId: string, response: textToSpeech.StopResponse) {
            console.info('[MuseumVoiceService] 停止播报：' + requestId + ', ' + JSON.stringify(response));
          },

          onData(requestId: string, audio: ArrayBuffer, response: textToSpeech.SynthesisResponse) {
            console.info('[MuseumVoiceService] 收到音频流：' + requestId + ', ' + JSON.stringify(response));
          },

          onError(requestId: string, errorCode: number, errorMessage: string) {
            console.error('[MuseumVoiceService] 播报错误：' + requestId + ', ' + errorCode + ', ' + errorMessage);
          }
        };

        engine.setListener(speakListener);
        resolve(engine);
      });
    });

    return MuseumVoiceService.creatingEngine;
  }

  /**
   * 内部播报方法
   * saveProgress = true：播放完整讲解，重新生成段落进度
   * saveProgress = false：只播放某一段，不重置完整段落列表
   */
  private static async speakInternal(
    text: string,
    speed: number = MuseumVoiceService.currentSpeed,
    saveProgress: boolean = true
  ): Promise<void> {
    if (!text || text.trim().length === 0) {
      promptAction.showToast({ message: '没有可播报的内容' });
      return;
    }

    try {
      let engine = await MuseumVoiceService.getTtsEngine();

      try {
        if (engine.isBusy()) {
          engine.stop();
        }
      } catch (error) {
        console.info('[MuseumVoiceService] 停止上一段播报失败，可忽略：' + JSON.stringify(error));
      }

      let finalText = text;
      if (finalText.length > 10000) {
        finalText = finalText.substring(0, 10000);
      }

      MuseumVoiceService.currentSpeed = speed;

      if (saveProgress) {
        MuseumVoiceService.currentText = finalText;
        MuseumVoiceService.paragraphs = MuseumVoiceService.splitText(finalText);
        MuseumVoiceService.paragraphIndex = 0;
      }

      let speakParams: textToSpeech.SpeakParams = {
        requestId: 'museum-' + Date.now().toString(),
        extraParams: {
          'queueMode': 0,
          'speed': speed,
          'volume': 2,
          'pitch': 1,
          'languageContext': 'zh-CN',
          'audioType': 'pcm',
          'soundChannel': 3,
          'playType': 1
        }
      };

      engine.speak(finalText, speakParams);
      promptAction.showToast({ message: `正在以 ${speed}x 倍速播放` });
    } catch (error) {
      let err = error as BusinessError;
      console.error('[MuseumVoiceService] 语音播放失败：' + JSON.stringify(error));
      promptAction.showToast({ message: '语音播放失败：' + (err.message || '请检查真机环境') });
    }
  }

  /**
   * 对外暴露的语音播报入口
   */
  static async speak(text: string, speed: number = MuseumVoiceService.currentSpeed): Promise<void> {
    await MuseumVoiceService.speakInternal(text, speed, true);
  }

  /**
   * 停止播放
   */
  static stop(): void {
    try {
      MuseumVoiceService.ttsEngine?.stop();
      promptAction.showToast({
        message: '已停止语音播放'
      });
    } catch (error) {
      console.error('[MuseumVoiceService] 停止播放失败：' + JSON.stringify(error));
    }
  }

  /**
   * 设置倍速
   */
  static setSpeed(speed: number): void {
    MuseumVoiceService.currentSpeed = speed;
    promptAction.showToast({ message: `已切换到 ${speed}x 倍速` });
  }

  static getSpeed(): number {
    return MuseumVoiceService.currentSpeed;
  }

  /**
   * 重播当前完整讲解
   */
  static replay(): void {
    if (MuseumVoiceService.currentText.length === 0) {
      promptAction.showToast({ message: '暂无可重播内容' });
      return;
    }

    MuseumVoiceService.speakInternal(
      MuseumVoiceService.currentText,
      MuseumVoiceService.currentSpeed,
      true
    );
  }

  /**
   * 上一段
   */
  static previousParagraph(): void {
    if (MuseumVoiceService.paragraphs.length === 0) {
      promptAction.showToast({ message: '暂无讲解段落' });
      return;
    }

    MuseumVoiceService.paragraphIndex = Math.max(0, MuseumVoiceService.paragraphIndex - 1);

    MuseumVoiceService.speakInternal(
      MuseumVoiceService.paragraphs[MuseumVoiceService.paragraphIndex],
      MuseumVoiceService.currentSpeed,
      false
    );
  }

  /**
   * 下一段
   */
  static nextParagraph(): void {
    if (MuseumVoiceService.paragraphs.length === 0) {
      promptAction.showToast({ message: '暂无讲解段落' });
      return;
    }

    MuseumVoiceService.paragraphIndex = Math.min(
      MuseumVoiceService.paragraphs.length - 1,
      MuseumVoiceService.paragraphIndex + 1
    );

    MuseumVoiceService.speakInternal(
      MuseumVoiceService.paragraphs[MuseumVoiceService.paragraphIndex],
      MuseumVoiceService.currentSpeed,
      false
    );
  }

  /**
   * 获取播放进度文字
   */
  static getProgressText(): string {
    if (MuseumVoiceService.paragraphs.length === 0) {
      return '0 / 0';
    }

    return `${MuseumVoiceService.paragraphIndex + 1} / ${MuseumVoiceService.paragraphs.length}`;
  }

  /**
   * 拆分讲解词，用于上一段 / 下一段
   */
  private static splitText(text: string): string[] {
    return text
      .split(/[。！？\n]/)
      .map((item: string) => item.trim())
      .filter((item: string) => item.length > 0);
  }

  /**
   * 根据文物信息生成讲解词
   */
  static buildArtifactGuide(artifact: Artifact): string {
    return `正在为你讲解${artifact.title}。
它的年代是${artifact.period}，类型是${artifact.type}，材质是${artifact.material}。
当前收藏机构是${artifact.museum}。
${artifact.description}`;
  }

  /**
   * 根据文字搜索文物
   */
  static searchArtifactByText(text: string): Artifact | null {
    let keyword = MuseumVoiceService.normalizeSearchText(text);

    if (keyword.length === 0) {
      return null;
    }

    for (let item of mockArtifacts) {
      let title = MuseumVoiceService.normalizeSearchText(item.title);
      let period = MuseumVoiceService.normalizeSearchText(item.period);
      let type = MuseumVoiceService.normalizeSearchText(item.type);
      let material = MuseumVoiceService.normalizeSearchText(item.material);
      let museum = MuseumVoiceService.normalizeSearchText(item.museum);
      let description = MuseumVoiceService.normalizeSearchText(item.description);

      if (
        title.includes(keyword) ||
          keyword.includes(title) ||
          period.includes(keyword) ||
          keyword.includes(period) ||
          type.includes(keyword) ||
          keyword.includes(type) ||
          material.includes(keyword) ||
          keyword.includes(material) ||
          museum.includes(keyword) ||
          keyword.includes(museum) ||
          description.includes(keyword)
      ) {
        return item;
      }
    }

    return null;
  }

  /**
   * 清洗语音搜索文字
   * 比如“帮我找青铜器”会处理成“青铜器”
   */
  private static normalizeSearchText(text: string): string {
    return text
      .replace(/\s/g, '')
      .replace(/[，。！？、,.!?]/g, '')
      .replace('我想搜索', '')
      .replace('我想看', '')
      .replace('帮我搜索', '')
      .replace('帮我查找', '')
      .replace('帮我找', '')
      .replace('搜索一下', '')
      .replace('查找一下', '')
      .replace('搜索', '')
      .replace('查找', '')
      .replace('寻找', '')
      .replace('看看', '')
      .trim();
  }

  /**
   * 处理语音搜索
   */
  static handleVoiceSearch(text: string): void {
    let artifact = MuseumVoiceService.searchArtifactByText(text);

    if (artifact) {
      MuseumVoiceService.speak(`已为你找到${artifact.title}`);

      router.pushUrl({
        url: 'pages/ArtifactDetailPage',
        params: {
          id: artifact.id
        }
      });
    } else {
      MuseumVoiceService.speak('没有找到相关文物，请换一个关键词试试');
    }
  }

  /**
   * 简单语音问答
   */
  static answerQuestion(artifact: Artifact, question: string): string {
    if (question.includes('哪里') || question.includes('在哪') || question.includes('博物馆') || question.includes('收藏')) {
      return `${artifact.title}目前收藏于${artifact.museum}。`;
    }

    if (question.includes('年代') || question.includes('什么时候') || question.includes('朝代')) {
      return `${artifact.title}的年代是${artifact.period}。`;
    }

    if (question.includes('材质') || question.includes('什么做')) {
      return `${artifact.title}的材质是${artifact.material}。`;
    }

    if (question.includes('类型') || question.includes('种类')) {
      return `${artifact.title}属于${artifact.type}。`;
    }

    if (question.includes('介绍') || question.includes('讲讲') || question.includes('是什么')) {
      return MuseumVoiceService.buildArtifactGuide(artifact);
    }

    return `关于${artifact.title}，我可以回答它的年代、类型、材质、收藏博物馆和文物介绍。`;
  }

  /**
   * 创建 / 获取 ASR 语音识别引擎
   */
  private static async getAsrEngine(): Promise<speechRecognizer.SpeechRecognitionEngine> {
    if (!canIUse('SystemCapability.AI.SpeechRecognizer')) {
      promptAction.showToast({
        message: '当前设备不支持语音识别'
      });
      throw new Error('当前设备不支持 SystemCapability.AI.SpeechRecognizer');
    }

    if (MuseumVoiceService.asrEngine !== null) {
      return MuseumVoiceService.asrEngine;
    }

    if (MuseumVoiceService.creatingAsrEngine !== null) {
      return MuseumVoiceService.creatingAsrEngine;
    }

    MuseumVoiceService.creatingAsrEngine = new Promise((resolve, reject) => {
      let initParams: speechRecognizer.CreateEngineParams = {
        language: 'zh-CN',
        online: 1,
        extraParams: {
          'locate': 'CN',
          'recognizerMode': 'short'
        }
      };

      speechRecognizer.createEngine(
        initParams,
        (err: BusinessError, engine: speechRecognizer.SpeechRecognitionEngine) => {
          MuseumVoiceService.creatingAsrEngine = null;

          if (err) {
            console.error('[MuseumVoiceService] 创建ASR引擎失败：' + JSON.stringify(err));
            reject(err);
            return;
          }

          MuseumVoiceService.asrEngine = engine;
          resolve(engine);
        }
      );
    });

    return MuseumVoiceService.creatingAsrEngine;
  }

  /**
   * 开始语音搜索：说出关键词，然后自动搜索文物
   */
  static async startVoiceSearch(onText: (text: string) => void): Promise<void> {
    try {
      let engine = await MuseumVoiceService.getAsrEngine();

      MuseumVoiceService.currentAsrSessionId = 'voice-search-' + Date.now().toString();

      let listener: speechRecognizer.RecognitionListener = {
        onStart(sessionId: string, eventMessage: string) {
          promptAction.showToast({ message: '请说出文物关键词' });
          console.info('[MuseumVoiceService] ASR开始：' + sessionId + ', ' + eventMessage);
        },

        onEvent(sessionId: string, eventCode: number, eventMessage: string) {
          console.info('[MuseumVoiceService] ASR事件：' + sessionId + ', ' + eventCode + ', ' + eventMessage);
        },

        onResult(sessionId: string, result: speechRecognizer.SpeechRecognitionResult) {
          console.info('[MuseumVoiceService] ASR结果：' + JSON.stringify(result));

          let text = MuseumVoiceService.parseAsrText(result);

          if (!text || text.trim().length === 0) {
            promptAction.showToast({ message: '没有识别到有效内容' });
            return;
          }

          onText(text);
          MuseumVoiceService.handleVoiceSearch(text);
        },

        onComplete(sessionId: string, eventMessage: string) {
          console.info('[MuseumVoiceService] ASR完成：' + sessionId + ', ' + eventMessage);
        },

        onError(sessionId: string, errorCode: number, errorMessage: string) {
          console.error('[MuseumVoiceService] ASR错误：' + sessionId + ', ' + errorCode + ', ' + errorMessage);
          promptAction.showToast({ message: '语音识别失败：' + errorMessage });
        }
      };

      engine.setListener(listener);

      let startParams: speechRecognizer.StartParams = {
        sessionId: MuseumVoiceService.currentAsrSessionId,
        audioInfo: {
          audioType: 'pcm',
          sampleRate: 16000,
          soundChannel: 1,
          sampleBit: 16
        },
        extraParams: {
          'recognitionMode': 0,
          'vadBegin': 2000,
          'vadEnd': 1500,
          'maxAudioDuration': 20000
        }
      };

      engine.startListening(startParams);
    } catch (error) {
      console.error('[MuseumVoiceService] 启动语音搜索失败：' + JSON.stringify(error));
      promptAction.showToast({ message: '启动语音搜索失败，请使用真机调试' });
    }
  }

  /**
   * 兼容不同 SDK 返回字段，尽量从 ASR 结果里解析文字
   */
  private static parseAsrText(result: speechRecognizer.SpeechRecognitionResult): string {
    let json = JSON.stringify(result);

    let patterns: RegExp[] = [
      /"result"\s*:\s*"([^"]+)"/,
      /"text"\s*:\s*"([^"]+)"/,
      /"sentence"\s*:\s*"([^"]+)"/
    ];

    for (let pattern of patterns) {
      let match = json.match(pattern);
      if (match !== null && match.length >= 2) {
        return match[1];
      }
    }

    return '';
  }

  /**
   * 结束语音搜索
   */
  static finishVoiceSearch(): void {
    try {
      if (MuseumVoiceService.asrEngine !== null && MuseumVoiceService.currentAsrSessionId.length > 0) {
        MuseumVoiceService.asrEngine.finish(MuseumVoiceService.currentAsrSessionId);
      }

      promptAction.showToast({ message: '已结束语音识别' });
    } catch (error) {
      console.error('[MuseumVoiceService] 结束语音搜索失败：' + JSON.stringify(error));
    }
  }
}
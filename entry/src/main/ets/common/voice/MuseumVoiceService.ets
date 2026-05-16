import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { Artifact, mockArtifacts } from '../models/Artifact';

export class MuseumVoiceService {
  /**
   * 语音播报入口
   * 目前先用 Toast + console 模拟语音播报
   * 后面接真实 TTS 的时候，只需要改这个函数
   */
  static speak(text: string): void {
    promptAction.showToast({
      message: '语音播报：' + text.substring(0, 20)
    });

    console.info('[MuseumVoiceService] speak: ' + text);
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
   * 这里的 text 后面可以替换成真实语音识别出来的文本
   */
  static searchArtifactByText(text: string): Artifact | null {
    let keyword = text.trim();

    if (keyword.length === 0) {
      return null;
    }

    for (let item of mockArtifacts) {
      if (
        item.title.includes(keyword) ||
          item.period.includes(keyword) ||
          item.type.includes(keyword) ||
          item.material.includes(keyword) ||
          item.museum.includes(keyword) ||
          item.description.includes(keyword)
      ) {
        return item;
      }
    }

    return null;
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
}
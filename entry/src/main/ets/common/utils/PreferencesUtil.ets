// common/utils/PreferencesUtil.ets
import preferences from '@ohos.data.preferences';

export class PreferencesUtil {
  private prefs: preferences.Preferences | null = null;

  async init(context: Context): Promise<void> {
    if (!this.prefs) {
      this.prefs = await preferences.getPreferences(context, 'PalmMuseumPrefs');
      console.info('[PreferencesUtil] 初始化成功');
    }
  }

  private ensureReady(): preferences.Preferences {
    if (!this.prefs) {
      throw new Error('[PreferencesUtil] prefs 未初始化，请先在 EntryAbility 中调用 preferencesUtil.init(context)');
    }
    return this.prefs;
  }

  async putString(key: string, value: string): Promise<void> {
    const prefs = this.ensureReady();
    await prefs.put(key, value);
    await prefs.flush();
    console.info(`[PreferencesUtil] 保存成功 key=${key}, value=${value}`);
  }

  async getString(key: string, def: string = ''): Promise<string> {
    const prefs = this.ensureReady();
    const value = await prefs.get(key, def) as string;
    console.info(`[PreferencesUtil] 读取成功 key=${key}, value=${value}`);
    return value;
  }

  async hasKey(key: string): Promise<boolean> {
    const prefs = this.ensureReady();
    return await prefs.has(key);
  }

  async clearAll(): Promise<void> {
    const prefs = this.ensureReady();
    await prefs.clear();
    await prefs.flush();
    console.info('[PreferencesUtil] 已清空全部本地数据');
  }
}

export const preferencesUtil = new PreferencesUtil();
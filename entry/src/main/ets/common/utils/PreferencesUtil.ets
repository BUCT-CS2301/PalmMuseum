// common/utils/PreferencesUtil.ets
import preferences from '@ohos.data.preferences';

export class PreferencesUtil {
  private prefs: preferences.Preferences | null = null;

  async init(context: Context) {
    if (!this.prefs) {
      this.prefs = await preferences.getPreferences(context, 'PalmMuseumPrefs');
    }
  }

  async putString(key: string, value: string) {
    if (this.prefs) {
      await this.prefs.put(key, value);
      await this.prefs.flush();
    }
  }

  async getString(key: string, def: string = ''): Promise<string> {
    if (this.prefs) {
      return await this.prefs.get(key, def) as string;
    }
    return def;
  }

  async hasKey(key: string): Promise<boolean> {
    if (this.prefs) {
      return await this.prefs.has(key);
    }
    return false;
  }

  async clearAll() {
    if (this.prefs) {
      await this.prefs.clear();
      await this.prefs.flush();
    }
  }
}

export const preferencesUtil = new PreferencesUtil();
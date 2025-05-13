import { Injectable, OnModuleInit } from '@nestjs/common';
import { ISettings } from '../../../common/interfaces/setting.interface';
import { CacheHelperUtil } from '../../../common/utils/cache-helper.util';
import { SETTINGS } from '../../../common/constants/setting.constant';
import { CACHE_KEYS } from 'src/common/constants/cache.constant';
import { UpdateSettingsDto } from './dto/setting.dto';

@Injectable()
export class SettingService implements OnModuleInit {
  async onModuleInit() {
    const settingsExist = await CacheHelperUtil.getCache(
      CACHE_KEYS.appSettings,
    );

    if (!settingsExist) {
      await CacheHelperUtil.setCache(CACHE_KEYS.appSettings, SETTINGS);
    }
  }

  async initialize() {
    await CacheHelperUtil.setCache(CACHE_KEYS.appSettings, SETTINGS);
  }

  async settings() {
    return await CacheHelperUtil.getCache(CACHE_KEYS.appSettings);
  }

  async updateSettings(payload: UpdateSettingsDto) {
    const prevSettings = (await CacheHelperUtil.getCache(
      CACHE_KEYS.appSettings,
    )) as ISettings;
    const updatedSettings = { ...prevSettings, ...payload };
    await CacheHelperUtil.setCache(CACHE_KEYS.appSettings, updatedSettings);
    return updatedSettings;
  }

  async deleteFromSettings(query: string[]) {
    const prevSettings = (await CacheHelperUtil.getCache(
      CACHE_KEYS.appSettings,
    )) as ISettings;
    const updatedSettings = { ...prevSettings };
    query.forEach((prop: string) => delete updatedSettings[prop]);
    await CacheHelperUtil.setCache(CACHE_KEYS.appSettings, updatedSettings);
    return updatedSettings;
  }
}

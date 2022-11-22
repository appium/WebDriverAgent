import { util } from '@appium/support';

export const PLATFORM_VERSION = process.env.PLATFORM_VERSION ? process.env.PLATFORM_VERSION : '11.3';
export const DEVICE_NAME = process.env.DEVICE_NAME
  || (util.compareVersions(PLATFORM_VERSION, '>=', '13.0') ? 'iPhone X' : 'iPhone 6');

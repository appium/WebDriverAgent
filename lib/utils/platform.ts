import {PLATFORM_NAME_TVOS, PLATFORM_NAME_WATCHOS} from '../constants.js';

/**
 * Return true if the platformName is tvOS
 * @param platformName The name of the platform
 * @returns Return true if the platformName is tvOS
 */
export function isTvOS(platformName: string): boolean {
  return platformName?.toLowerCase() === PLATFORM_NAME_TVOS.toLowerCase();
}

/**
 * Return true if the platformName is watchOS
 * @param platformName The name of the platform
 * @returns Return true if the platformName is watchOS
 */
export function isWatchOS(platformName: string): boolean {
  return platformName?.toLowerCase() === PLATFORM_NAME_WATCHOS.toLowerCase();
}

/**
 * @param platformName The name of the platform
 * @returns The `WebDriverAgentRunner`/`WebDriverAgentLib` scheme name suffix for the given platform:
 * '_tvOS', '_watchOS', or '' for iOS.
 */
export function getPlatformSchemeSuffix(platformName: string): string {
  if (isTvOS(platformName)) {
    return '_tvOS';
  }
  if (isWatchOS(platformName)) {
    return '_watchOS';
  }
  return '';
}

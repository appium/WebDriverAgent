import {PLATFORM_NAME_TVOS} from '../constants';

/**
 * Return true if the platformName is tvOS
 * @param platformName The name of the platform
 * @returns Return true if the platformName is tvOS
 */
export function isTvOS(platformName: string): boolean {
  return platformName?.toLowerCase() === PLATFORM_NAME_TVOS.toLowerCase();
}

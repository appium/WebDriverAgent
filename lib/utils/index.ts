import {getWDAUpgradeTimestamp as getWDAUpgradeTimestampImpl} from './module.js';

export {BOOTSTRAP_PATH} from './module.js';
export {isTvOS} from './platform.js';
export {getPIDsListeningOnPort, killAppUsingPattern, resetTestProcesses} from './processes.js';
export {setRealDeviceSecurity} from './security.js';
export {
  getAdditionalRunContent,
  getXctestrunFileName,
  getXctestrunFilePath,
  setXctestrunFile,
} from './xctestrun.js';
export type {XctestrunFileArgs} from './xctestrun.js';

/**
 * Retrieves WDA upgrade timestamp. The manifest only gets modified on package upgrade.
 */
export async function getWDAUpgradeTimestamp(): Promise<number | null> {
  return await getWDAUpgradeTimestampImpl();
}

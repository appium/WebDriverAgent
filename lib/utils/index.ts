import {getWDAUpgradeTimestamp as getWDAUpgradeTimestampImpl} from './module';

export {BOOTSTRAP_PATH} from './module';
export {isTvOS} from './platform';
export {getPIDsListeningOnPort, killAppUsingPattern, resetTestProcesses} from './processes';
export {setRealDeviceSecurity} from './security';
export {
  getAdditionalRunContent,
  getXctestrunFileName,
  getXctestrunFilePath,
  setXctestrunFile,
} from './xctestrun';
export type {XctestrunFileArgs} from './xctestrun';

/**
 * Retrieves WDA upgrade timestamp. The manifest only gets modified on package upgrade.
 */
export async function getWDAUpgradeTimestamp(): Promise<number | null> {
  return await getWDAUpgradeTimestampImpl();
}

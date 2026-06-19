import {exec} from 'teen_process';
import {log} from '../logger';

/**
 * Configure keychain access required for real-device code signing.
 */
export async function setRealDeviceSecurity(
  keychainPath: string,
  keychainPassword: string,
): Promise<void> {
  log.debug('Setting security for iOS device');
  await exec('security', ['-v', 'list-keychains', '-s', keychainPath]);
  await exec('security', ['-v', 'unlock-keychain', '-p', keychainPassword, keychainPath]);
  await exec('security', ['set-keychain-settings', '-t', '3600', '-l', keychainPath]);
}

import { fs, plist } from '@appium/support';
import { exec, SubProcess } from 'teen_process';
import path, { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { log } from './logger';
import _ from 'lodash';
import { WDA_RUNNER_BUNDLE_ID, PLATFORM_NAME_TVOS } from './constants';
import B from 'bluebird';
import _fs from 'node:fs';
import { waitForCondition } from 'asyncbox';
import { arch } from 'node:os';
import type { DeviceInfo } from './types';

const PROJECT_FILE = 'project.pbxproj';

// Get current filename - works in both CommonJS and ESM
const currentFilename =
  typeof __filename !== 'undefined'
    ? __filename
    : fileURLToPath(new Function('return import.meta.url')());

const currentDirname = dirname(currentFilename);

/**
 * Calculates the path to the current module's root folder
 *
 * @returns {string} The full path to module root
 * @throws {Error} If the current module root folder cannot be determined
 */
const getModuleRoot = _.memoize(function getModuleRoot (): string {
  let currentDir = currentDirname;
  let isAtFsRoot = false;
  while (!isAtFsRoot) {
    const manifestPath = path.join(currentDir, 'package.json');
    try {
      if (_fs.existsSync(manifestPath) &&
          JSON.parse(_fs.readFileSync(manifestPath, 'utf8')).name === 'appium-webdriveragent') {
        return currentDir;
      }
    } catch {}
    currentDir = path.dirname(currentDir);
    isAtFsRoot = currentDir.length <= path.dirname(currentDir).length;
  }
  throw new Error('Cannot find the root folder of the appium-webdriveragent Node.js module');
});

export const BOOTSTRAP_PATH = getModuleRoot();

export async function killAppUsingPattern (pgrepPattern: string): Promise<void> {
  const signals = [2, 15, 9];
  for (const signal of signals) {
    const matchedPids = await getPIDsUsingPattern(pgrepPattern);
    if (_.isEmpty(matchedPids)) {
      return;
    }
    const args = [`-${signal}`, ...matchedPids];
    try {
      await exec('kill', args);
    } catch (err: any) {
      log.debug(`kill ${args.join(' ')} -> ${err.message}`);
    }
    if (signal === _.last(signals)) {
      // there is no need to wait after SIGKILL
      return;
    }
    try {
      await waitForCondition(async () => {
        const pidCheckPromises = matchedPids
          .map((pid) => exec('kill', ['-0', pid])
            // the process is still alive
            .then(() => false)
            // the process is dead
            .catch(() => true)
          );
        return (await B.all(pidCheckPromises))
          .every((x) => x === true);
      }, {
        waitMs: 1000,
        intervalMs: 100,
      });
      return;
    } catch {
      // try the next signal
    }
  }
}

/**
 * Return true if the platformName is tvOS
 * @param platformName The name of the platorm
 * @returns Return true if the platformName is tvOS
 */
export function isTvOS (platformName: string): boolean {
  return _.toLower(platformName) === _.toLower(PLATFORM_NAME_TVOS);
}

/**
 * Update WebDriverAgentRunner project bundle ID with newBundleId.
 * This method assumes project file is in the correct state.
 * @param agentPath - Path to the .xcodeproj directory.
 * @param newBundleId the new bundle ID used to update.
 */
export async function updateProjectFile (agentPath: string, newBundleId: string): Promise<void> {
  const projectFilePath = path.resolve(agentPath, PROJECT_FILE);
  try {
    // Assuming projectFilePath is in the correct state, create .old from projectFilePath
    await fs.copyFile(projectFilePath, `${projectFilePath}.old`);
    await replaceInFile(projectFilePath, new RegExp(_.escapeRegExp(WDA_RUNNER_BUNDLE_ID), 'g'), newBundleId);
    log.debug(`Successfully updated '${projectFilePath}' with bundle id '${newBundleId}'`);
  } catch (err: any) {
    log.debug(`Error updating project file: ${err.message}`);
    log.warn(`Unable to update project file '${projectFilePath}' with ` +
      `bundle id '${newBundleId}'. WebDriverAgent may not start`);
  }
}

/**
 * Reset WebDriverAgentRunner project bundle ID to correct state.
 * @param agentPath - Path to the .xcodeproj directory.
 */
export async function resetProjectFile (agentPath: string): Promise<void> {
  const projectFilePath = path.join(agentPath, PROJECT_FILE);
  try {
    // restore projectFilePath from .old file
    if (!await fs.exists(`${projectFilePath}.old`)) {
      return; // no need to reset
    }
    await fs.mv(`${projectFilePath}.old`, projectFilePath);
    log.debug(`Successfully reset '${projectFilePath}' with bundle id '${WDA_RUNNER_BUNDLE_ID}'`);
  } catch (err: any) {
    log.debug(`Error resetting project file: ${err.message}`);
    log.warn(`Unable to reset project file '${projectFilePath}' with ` +
      `bundle id '${WDA_RUNNER_BUNDLE_ID}'. WebDriverAgent has been ` +
      `modified and not returned to the original state.`);
  }
}

export async function setRealDeviceSecurity (keychainPath: string, keychainPassword: string): Promise<void> {
  log.debug('Setting security for iOS device');
  await exec('security', ['-v', 'list-keychains', '-s', keychainPath]);
  await exec('security', ['-v', 'unlock-keychain', '-p', keychainPassword, keychainPath]);
  await exec('security', ['set-keychain-settings', '-t', '3600', '-l', keychainPath]);
}

/**
 * Arguments for setting xctestrun file
 */
export interface XctestrunFileArgs {
  deviceInfo: DeviceInfo;
  sdkVersion: string;
  bootstrapPath: string;
  wdaRemotePort: number | string;
  wdaBindingIP?: string;
}

/**
 * Creates xctestrun file per device & platform version.
 * We expects to have WebDriverAgentRunner_iphoneos${sdkVersion|platformVersion}-arm64.xctestrun for real device
 * and WebDriverAgentRunner_iphonesimulator${sdkVersion|platformVersion}-${x86_64|arm64}.xctestrun for simulator located @bootstrapPath
 * Newer Xcode (Xcode 10.0 at least) generate xctestrun file following sdkVersion.
 * e.g. Xcode which has iOS SDK Version 12.2 on an intel Mac host machine generates WebDriverAgentRunner_iphonesimulator.2-x86_64.xctestrun
 *      even if the cap has platform version 11.4
 *
 * @param args
 * @return returns xctestrunFilePath for given device
 * @throws if WebDriverAgentRunner_iphoneos${sdkVersion|platformVersion}-arm64.xctestrun for real device
 * or WebDriverAgentRunner_iphonesimulator${sdkVersion|platformVersion}-x86_64.xctestrun for simulator is not found @bootstrapPath,
 * then it will throw a file not found exception
 */
export async function setXctestrunFile (args: XctestrunFileArgs): Promise<string> {
  const {deviceInfo, sdkVersion, bootstrapPath, wdaRemotePort, wdaBindingIP} = args;
  const xctestrunFilePath = await getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath);
  const xctestRunContent = await plist.parsePlistFile(xctestrunFilePath);
  const updateWDAPort = getAdditionalRunContent(deviceInfo.platformName, wdaRemotePort, wdaBindingIP);
  const newXctestRunContent = _.merge(xctestRunContent, updateWDAPort);
  await plist.updatePlistFile(xctestrunFilePath, newXctestRunContent, true);

  return xctestrunFilePath;
}

/**
 * Return the WDA object which appends existing xctest runner content
 * @param platformName - The name of the platform
 * @param wdaRemotePort - The remote port number
 * @param wdaBindingIP - The IP address to bind to. If not given, it binds to all interfaces.
 * @return returns a runner object which has USE_PORT and optionally USE_IP
 */
export function getAdditionalRunContent (platformName: string, wdaRemotePort: number | string, wdaBindingIP?: string): Record<string, any> {
  const runner = `WebDriverAgentRunner${isTvOS(platformName) ? '_tvOS' : ''}`;
  return {
    [runner]: {
      EnvironmentVariables: {
        // USE_PORT must be 'string'
        USE_PORT: `${wdaRemotePort}`,
        ...(wdaBindingIP ? { USE_IP: wdaBindingIP } : {}),
      }
    }
  };
}

/**
 * Return the path of xctestrun if it exists
 * @param deviceInfo
 * @param sdkVersion - The Xcode SDK version of OS.
 * @param bootstrapPath - The folder path containing xctestrun file.
 */
export async function getXctestrunFilePath (deviceInfo: DeviceInfo, sdkVersion: string, bootstrapPath: string): Promise<string> {
  // First try the SDK path, for Xcode 10 (at least)
  const sdkBased: [string, string] = [
    path.resolve(bootstrapPath, `${deviceInfo.udid}_${sdkVersion}.xctestrun`),
    sdkVersion,
  ];
  // Next try Platform path, for earlier Xcode versions
  const platformBased: [string, string] = [
    path.resolve(bootstrapPath, `${deviceInfo.udid}_${deviceInfo.platformVersion}.xctestrun`),
    deviceInfo.platformVersion,
  ];

  for (const [filePath, version] of [sdkBased, platformBased]) {
    if (await fs.exists(filePath)) {
      log.info(`Using '${filePath}' as xctestrun file`);
      return filePath;
    }
    const originalXctestrunFile = path.resolve(bootstrapPath, getXctestrunFileName(deviceInfo, version));
    if (await fs.exists(originalXctestrunFile)) {
      // If this is first time run for given device, then first generate xctestrun file for device.
      // We need to have a xctestrun file **per device** because we cant not have same wda port for all devices.
      await fs.copyFile(originalXctestrunFile, filePath);
      log.info(`Using '${filePath}' as xctestrun file copied by '${originalXctestrunFile}'`);
      return filePath;
    }
  }

  throw new Error(
    `If you are using 'useXctestrunFile' capability then you ` +
    `need to have a xctestrun file (expected: ` +
    `'${path.resolve(bootstrapPath, getXctestrunFileName(deviceInfo, sdkVersion))}')`
  );
}


/**
 * Return the name of xctestrun file
 * @param deviceInfo
 * @param version - The Xcode SDK version of OS.
 * @return returns xctestrunFilePath for given device
 */
export function getXctestrunFileName (deviceInfo: DeviceInfo, version: string): string {
  const archSuffix = deviceInfo.isRealDevice
    ? `os${version}-arm64`
    : `simulator${version}-${arch() === 'arm64' ? 'arm64' : 'x86_64'}`;
  return `WebDriverAgentRunner_${isTvOS(deviceInfo.platformName) ? 'tvOS_appletv' : 'iphone'}${archSuffix}.xctestrun`;
}

/**
 * Ensures the process is killed after the timeout
 */
export async function killProcess (name: string, proc: SubProcess | null | undefined): Promise<void> {
  if (!proc || !proc.isRunning) {
    return;
  }

  log.info(`Shutting down '${name}' process (pid '${proc.proc?.pid}')`);

  log.info(`Sending 'SIGTERM'...`);
  try {
    await proc.stop('SIGTERM', 1000);
    return;
  } catch (err: any) {
    if (!err.message.includes(`Process didn't end after`)) {
      throw err;
    }
    log.debug(`${name} process did not end in a timely fashion: '${err.message}'.`);
  }

  log.info(`Sending 'SIGKILL'...`);
  try {
    await proc.stop('SIGKILL');
  } catch (err: any) {
    if (err.message.includes('not currently running')) {
      // the process ended but for some reason we were not informed
      return;
    }
    throw err;
  }
}

/**
 * Generate a random integer in range [low, high). `low` is inclusive and `high` is exclusive.
 */
export function randomInt (low: number, high: number): number {
  return Math.floor(Math.random() * (high - low) + low);
}

/**
 * Retrieves WDA upgrade timestamp. The manifest only gets modified on package upgrade.
 */
export async function getWDAUpgradeTimestamp (): Promise<number | null> {
  const packageManifest = path.resolve(getModuleRoot(), 'package.json');
  if (!await fs.exists(packageManifest)) {
    return null;
  }
  const {mtime} = await fs.stat(packageManifest);
  return mtime.getTime();
}

/**
 * Kills running XCTest processes for the particular device.
 */
export async function resetTestProcesses (udid: string, isSimulator: boolean): Promise<void> {
  const processPatterns = [`xcodebuild.*${udid}`];
  if (isSimulator) {
    processPatterns.push(`${udid}.*XCTRunner`);
    // The pattern to find in case idb was used
    processPatterns.push(`xctest.*${udid}`);
  }
  log.debug(`Killing running processes '${processPatterns.join(', ')}' for the device ${udid}...`);
  await B.all(processPatterns.map(killAppUsingPattern));
}

/**
 * Get the IDs of processes listening on the particular system port.
 * It is also possible to apply additional filtering based on the
 * process command line.
 *
 * @param port - The port number.
 * @param filteringFunc - Optional lambda function, which
 *                                    receives command line string of the particular process
 *                                    listening on given port, and is expected to return
 *                                    either true or false to include/exclude the corresponding PID
 *                                    from the resulting array.
 * @returns - the list of matched process ids.
 */
export async function getPIDsListeningOnPort (port: string | number, filteringFunc: ((cmdline: string) => boolean | Promise<boolean>) | null = null): Promise<string[]> {
  const result: string[] = [];
  try {
    // This only works since Mac OS X El Capitan
    const {stdout} = await exec('lsof', ['-ti', `tcp:${port}`]);
    result.push(...(stdout.trim().split(/\n+/)));
  } catch (e: any) {
    if (e.code !== 1) {
      // code 1 means no processes. Other errors need reporting
      log.debug(`Error getting processes listening on port '${port}': ${e.stderr || e.message}`);
    }
    return result;
  }

  if (!_.isFunction(filteringFunc)) {
    return result;
  }
  return await B.filter(result, async (pid) => {
    let stdout: string;
    try {
      ({stdout} = await exec('ps', ['-p', pid, '-o', 'command']));
    } catch (e: any) {
      if (e.code === 1) {
        // The process does not exist anymore, there's nothing to filter
        return false;
      }
      throw e;
    }
    return await filteringFunc(stdout);
  });
}

// Private functions

async function getPIDsUsingPattern (pattern: string): Promise<string[]> {
  const args = [
    '-if', // case insensitive, full cmdline match
    pattern,
  ];
  try {
    const {stdout} = await exec('pgrep', args);
    return stdout.split(/\s+/)
      .map((x) => parseInt(x, 10))
      .filter(_.isInteger)
      .map((x) => `${x}`);
  } catch (err: any) {
    log.debug(`'pgrep ${args.join(' ')}' didn't detect any matching processes. Return code: ${err.code}`);
    return [];
  }
}

async function replaceInFile (file: string, find: string | RegExp, replace: string): Promise<void> {
  const contents = await fs.readFile(file, 'utf8');

  const newContents = contents.replace(find, replace);
  if (newContents !== contents) {
    await fs.writeFile(file, newContents, 'utf8');
  }
}


import { fs, tempDir, plist } from 'appium-support';
import { exec } from 'teen_process';
import path from 'path';
import log from './logger';
import _ from 'lodash';
import { WDA_RUNNER_BUNDLE_ID, PLATFORM_NAME_TVOS } from './constants';
import B from 'bluebird';
import { waitForCondition } from 'asyncbox';

const ROOT_DIR = path.basename(__dirname) === 'lib'
  ? path.resolve(__dirname, process.env.NO_PRECOMPILE ? '..' : '../..')
  : __dirname;
const PROJECT_FILE = 'project.pbxproj';

async function getPIDsUsingPattern (pattern) {
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
  } catch (err) {
    log.debug(`'pgrep ${args.join(' ')}' didn't detect any matching processes. Return code: ${err.code}`);
    return [];
  }
}

async function killAppUsingPattern (pgrepPattern) {
  const signals = [2, 15, 9];
  for (const signal of signals) {
    const matchedPids = await getPIDsUsingPattern(pgrepPattern);
    if (_.isEmpty(matchedPids)) {
      return;
    }
    const args = [`-${signal}`, ...matchedPids];
    try {
      await exec('kill', args);
    } catch (err) {
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
    } catch (ign) {
      // try the next signal
    }
  }
}

/**
 * Return true if the platformName is tvOS
 * @param {string} platformName The name of the platorm
 * @returns {boolean} Return true if the platformName is tvOS
 */
function isTvOS (platformName) {
  return _.toLower(platformName) === _.toLower(PLATFORM_NAME_TVOS);
}

async function replaceInFile (file, find, replace) {
  let contents = await fs.readFile(file, 'utf8');

  let newContents = contents.replace(find, replace);
  if (newContents !== contents) {
    await fs.writeFile(file, newContents, 'utf8');
  }
}

/**
 * Update WebDriverAgentRunner project bundle ID with newBundleId.
 * This method assumes project file is in the correct state.
 * @param {string} agentPath - Path to the .xcodeproj directory.
 * @param {string} newBundleId the new bundle ID used to update.
 */
async function updateProjectFile (agentPath, newBundleId) {
  let projectFilePath = path.resolve(agentPath, PROJECT_FILE);
  try {
    // Assuming projectFilePath is in the correct state, create .old from projectFilePath
    await fs.copyFile(projectFilePath, `${projectFilePath}.old`);
    await replaceInFile(projectFilePath, new RegExp(_.escapeRegExp(WDA_RUNNER_BUNDLE_ID), 'g'), newBundleId); // eslint-disable-line no-useless-escape
    log.debug(`Successfully updated '${projectFilePath}' with bundle id '${newBundleId}'`);
  } catch (err) {
    log.debug(`Error updating project file: ${err.message}`);
    log.warn(`Unable to update project file '${projectFilePath}' with ` +
      `bundle id '${newBundleId}'. WebDriverAgent may not start`);
  }
}

/**
 * Reset WebDriverAgentRunner project bundle ID to correct state.
 * @param {string} agentPath - Path to the .xcodeproj directory.
 */
async function resetProjectFile (agentPath) {
  const projectFilePath = path.join(agentPath, PROJECT_FILE);
  try {
    // restore projectFilePath from .old file
    if (!await fs.exists(`${projectFilePath}.old`)) {
      return; // no need to reset
    }
    await fs.mv(`${projectFilePath}.old`, projectFilePath);
    log.debug(`Successfully reset '${projectFilePath}' with bundle id '${WDA_RUNNER_BUNDLE_ID}'`);
  } catch (err) {
    log.debug(`Error resetting project file: ${err.message}`);
    log.warn(`Unable to reset project file '${projectFilePath}' with ` +
      `bundle id '${WDA_RUNNER_BUNDLE_ID}'. WebDriverAgent has been ` +
      `modified and not returned to the original state.`);
  }
}

async function setRealDeviceSecurity (keychainPath, keychainPassword) {
  log.debug('Setting security for iOS device');
  await exec('security', ['-v', 'list-keychains', '-s', keychainPath]);
  await exec('security', ['-v', 'unlock-keychain', '-p', keychainPassword, keychainPath]);
  await exec('security', ['set-keychain-settings', '-t', '3600', '-l', keychainPath]);
}

async function generateXcodeConfigFile (orgId, signingId) {
  log.debug(`Generating xcode config file for orgId '${orgId}' and signingId ` +
            `'${signingId}'`);
  const contents = `DEVELOPMENT_TEAM = ${orgId}
CODE_SIGN_IDENTITY = ${signingId}
`;
  const xcconfigPath = await tempDir.path('appium-temp.xcconfig');
  log.debug(`Writing xcode config file to ${xcconfigPath}`);
  await fs.writeFile(xcconfigPath, contents, 'utf8');
  return xcconfigPath;
}

/**
 * Information of the device under test
 * @typedef {Object} DeviceInfo
 * @property {string} isRealDevice - Equals to true if the current device is a real device
 * @property {string} udid - The device UDID.
 * @property {string} platformVersion - The platform version of OS.
 * @property {string} platformName - The platform name of iOS, tvOS
*/
/**
 * Creates xctestrun file per device & platform version.
 * We expects to have WebDriverAgentRunner_iphoneos${sdkVersion|platformVersion}-arm64.xctestrun for real device
 * and WebDriverAgentRunner_iphonesimulator${sdkVersion|platformVersion}-x86_64.xctestrun for simulator located @bootstrapPath
 * Newer Xcode (Xcode 10.0 at least) generate xctestrun file following sdkVersion.
 * e.g. Xcode which has iOS SDK Version 12.2 generate WebDriverAgentRunner_iphonesimulator.2-x86_64.xctestrun
 *      even if the cap has platform version 11.4
 *
 * @param {DeviceInfo} deviceInfo
 * @param {string} sdkVersion - The Xcode SDK version of OS.
 * @param {string} bootstrapPath - The folder path containing xctestrun file.
 * @param {string} wdaRemotePort - The remote port WDA is listening on.
 * @return {string} returns xctestrunFilePath for given device
 * @throws if WebDriverAgentRunner_iphoneos${sdkVersion|platformVersion}-arm64.xctestrun for real device
 * or WebDriverAgentRunner_iphonesimulator${sdkVersion|platformVersion}-x86_64.xctestrun for simulator is not found @bootstrapPath,
 * then it will throw file not found exception
 */
async function setXctestrunFile (deviceInfo, sdkVersion, bootstrapPath, wdaRemotePort) {
  const xctestrunFilePath = await getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath);
  const xctestRunContent = await plist.parsePlistFile(xctestrunFilePath);
  const updateWDAPort = getAdditionalRunContent(deviceInfo.platformName, wdaRemotePort);
  const newXctestRunContent = _.merge(xctestRunContent, updateWDAPort);
  await plist.updatePlistFile(xctestrunFilePath, newXctestRunContent, true);

  return xctestrunFilePath;
}

/**
 * Return the WDA object which appends existing xctest runner content
 * @param {string} platformName - The name of the platform
 * @param {string} version - The Xcode SDK version of OS.
 * @return {object} returns a runner object which has USE_PORT
 */
function getAdditionalRunContent (platformName, wdaRemotePort) {
  const runner = `WebDriverAgentRunner${isTvOS(platformName) ? '_tvOS' : ''}`;

  return {
    [runner]: {
      EnvironmentVariables: {
        // USE_PORT must be 'string'
        USE_PORT: `${wdaRemotePort}`
      }
    }
  };
}

/**
 * Return the path of xctestrun if it exists
 * @param {DeviceInfo} deviceInfo
 * @param {string} sdkVersion - The Xcode SDK version of OS.
 * @param {string} bootstrapPath - The folder path containing xctestrun file.
 */
async function getXctestrunFilePath (deviceInfo, sdkVersion, bootstrapPath) {
  // First try the SDK path, for Xcode 10 (at least)
  const sdkBased = [
    path.resolve(bootstrapPath, `${deviceInfo.udid}_${sdkVersion}.xctestrun`),
    sdkVersion,
  ];
  // Next try Platform path, for earlier Xcode versions
  const platformBased = [
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

  log.errorAndThrow(`If you are using 'useXctestrunFile' capability then you ` +
    `need to have a xctestrun file (expected: ` +
    `'${path.resolve(bootstrapPath, getXctestrunFileName(deviceInfo, sdkVersion))}')`);
}


/**
 * Return the name of xctestrun file
 * @param {DeviceInfo} deviceInfo
 * @param {string} version - The Xcode SDK version of OS.
 * @return {string} returns xctestrunFilePath for given device
 */
function getXctestrunFileName (deviceInfo, version) {
  return isTvOS(deviceInfo.platformName)
    ? `WebDriverAgentRunner_tvOS_appletv${deviceInfo.isRealDevice ? `os${version}-arm64` : `simulator${version}-x86_64`}.xctestrun`
    : `WebDriverAgentRunner_iphone${deviceInfo.isRealDevice ? `os${version}-arm64` : `simulator${version}-x86_64`}.xctestrun`;
}

async function killProcess (name, proc) {
  if (!proc || !proc.isRunning) {
    return;
  }

  log.info(`Shutting down '${name}' process (pid '${proc.proc.pid}')`);

  log.info(`Sending 'SIGTERM'...`);
  try {
    await proc.stop('SIGTERM', 1000);
    return;
  } catch (err) {
    if (!err.message.includes(`Process didn't end after`)) {
      throw err;
    }
    log.debug(`${name} process did not end in a timely fashion: '${err.message}'.`);
  }

  log.info(`Sending 'SIGKILL'...`);
  try {
    await proc.stop('SIGKILL');
  } catch (err) {
    if (err.message.includes('not currently running')) {
      // the process ended but for some reason we were not informed
      return;
    }
    throw err;
  }
}

/**
 * Generate a random integer.
 *
 * @return {number} A random integer number in range [low, hight). `low`` is inclusive and `high` is exclusive.
 */
function randomInt (low, high) {
  return Math.floor(Math.random() * (high - low) + low);
}

/**
 * Retrieves WDA upgrade timestamp
 *
 * @return {?number} The UNIX timestamp of the package manifest. The manifest only gets modified on
 * package upgrade.
 */
async function getWDAUpgradeTimestamp () {
  const packageManifest = path.resolve(ROOT_DIR, 'package.json');
  if (!await fs.exists(packageManifest)) {
    return null;
  }
  const {mtime} = await fs.stat(packageManifest);
  return mtime.getTime();
}

/**
 * Kills running XCTest processes for the particular device.
 *
 * @param {string} udid - The device UDID.
 * @param {boolean} isSimulator - Equals to true if the current device is a Simulator
 */
async function resetTestProcesses (udid, isSimulator) {
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
 * @param {string|number} port - The port number.
 * @param {?Function} filteringFunc - Optional lambda function, which
 *                                    receives command line string of the particular process
 *                                    listening on given port, and is expected to return
 *                                    either true or false to include/exclude the corresponding PID
 *                                    from the resulting array.
 * @returns {Array<string>} - the list of matched process ids.
 */
async function getPIDsListeningOnPort (port, filteringFunc = null) {
  const result = [];
  try {
    // This only works since Mac OS X El Capitan
    const {stdout} = await exec('lsof', ['-ti', `tcp:${port}`]);
    result.push(...(stdout.trim().split(/\n+/)));
  } catch (e) {
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
    let stdout;
    try {
      ({stdout} = await exec('ps', ['-p', pid, '-o', 'command']));
    } catch (e) {
      if (e.code === 1) {
        // The process does not exist anymore, there's nothing to filter
        return false;
      }
      throw e;
    }
    return await filteringFunc(stdout);
  });
}

export { updateProjectFile, resetProjectFile, setRealDeviceSecurity,
  getAdditionalRunContent, getXctestrunFileName, generateXcodeConfigFile,
  setXctestrunFile, getXctestrunFilePath, killProcess, randomInt,
  getWDAUpgradeTimestamp, resetTestProcesses,
  getPIDsListeningOnPort, killAppUsingPattern, isTvOS,
};

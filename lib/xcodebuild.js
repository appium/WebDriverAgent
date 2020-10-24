import { retryInterval } from 'asyncbox';
import { SubProcess, exec } from 'teen_process';
import { fs, logger, timing } from 'appium-support';
import log from './logger';
import B from 'bluebird';
import {
  setRealDeviceSecurity, generateXcodeConfigFile, setXctestrunFile,
  updateProjectFile, resetProjectFile, killProcess,
  getWDAUpgradeTimestamp, isTvOS } from './utils';
import _ from 'lodash';
import path from 'path';
import { EOL } from 'os';
import { WDA_RUNNER_BUNDLE_ID } from './constants';


const DEFAULT_SIGNING_ID = 'iPhone Developer';
const PREBUILD_DELAY = 0;
const RUNNER_SCHEME_IOS = 'WebDriverAgentRunner';
const LIB_SCHEME_IOS = 'WebDriverAgentLib';

const ERROR_WRITING_ATTACHMENT = 'Error writing attachment data to file';
const ERROR_COPYING_ATTACHMENT = 'Error copying testing attachment';
const IGNORED_ERRORS = [
  ERROR_WRITING_ATTACHMENT,
  ERROR_COPYING_ATTACHMENT,
  'Failed to remove screenshot at path',
];

const RUNNER_SCHEME_TV = 'WebDriverAgentRunner_tvOS';
const LIB_SCHEME_TV = 'WebDriverAgentLib_tvOS';

const xcodeLog = logger.getLogger('Xcode');


class XcodeBuild {
  constructor (xcodeVersion, device, args = {}) {
    this.xcodeVersion = xcodeVersion;

    this.device = device;

    this.realDevice = args.realDevice;

    this.agentPath = args.agentPath;
    this.bootstrapPath = args.bootstrapPath;

    this.platformVersion = args.platformVersion;
    this.platformName = args.platformName;
    this.iosSdkVersion = args.iosSdkVersion;

    this.showXcodeLog = args.showXcodeLog;

    this.xcodeConfigFile = args.xcodeConfigFile;
    this.xcodeOrgId = args.xcodeOrgId;
    this.xcodeSigningId = args.xcodeSigningId || DEFAULT_SIGNING_ID;
    this.keychainPath = args.keychainPath;
    this.keychainPassword = args.keychainPassword;

    this.prebuildWDA = args.prebuildWDA;
    this.usePrebuiltWDA = args.usePrebuiltWDA;
    this.useSimpleBuildTest = args.useSimpleBuildTest;

    this.useXctestrunFile = args.useXctestrunFile;

    this.launchTimeout = args.launchTimeout;

    this.wdaRemotePort = args.wdaRemotePort;

    this.updatedWDABundleId = args.updatedWDABundleId;
    this.derivedDataPath = args.derivedDataPath;

    this.mjpegServerPort = args.mjpegServerPort;

    this.prebuildDelay = _.isNumber(args.prebuildDelay) ? args.prebuildDelay : PREBUILD_DELAY;

    this.allowProvisioningDeviceRegistration = args.allowProvisioningDeviceRegistration;

    this.resultBundlePath = args.resultBundlePath;
    this.resultBundleVersion = args.resultBundleVersion;
  }

  async init (noSessionProxy) {
    this.noSessionProxy = noSessionProxy;

    if (this.useXctestrunFile) {
      const deviveInfo = {
        isRealDevice: this.realDevice,
        udid: this.device.udid,
        platformVersion: this.platformVersion,
        platformName: this.platformName
      };
      this.xctestrunFilePath = await setXctestrunFile(deviveInfo, this.iosSdkVersion, this.bootstrapPath, this.wdaRemotePort);
      return;
    }

    // if necessary, update the bundleId to user's specification
    if (this.realDevice) {
      // In case the project still has the user specific bundle ID, reset the project file first.
      // - We do this reset even if updatedWDABundleId is not specified,
      //   since the previous updatedWDABundleId test has generated the user specific bundle ID project file.
      // - We don't call resetProjectFile for simulator,
      //   since simulator test run will work with any user specific bundle ID.
      await resetProjectFile(this.agentPath);
      if (this.updatedWDABundleId) {
        await updateProjectFile(this.agentPath, this.updatedWDABundleId);
      }
    }
  }

  async retrieveDerivedDataPath () {
    if (this.derivedDataPath) {
      return this.derivedDataPath;
    }

    // avoid race conditions
    if (this._derivedDataPathPromise) {
      return await this._derivedDataPathPromise;
    }

    this._derivedDataPathPromise = (async () => {
      let stdout;
      try {
        ({stdout} = await exec('xcodebuild', ['-project', this.agentPath, '-showBuildSettings']));
      } catch (err) {
        log.warn(`Cannot retrieve WDA build settings. Original error: ${err.message}`);
        return;
      }

      const pattern = /^\s*BUILD_DIR\s+=\s+(\/.*)/m;
      const match = pattern.exec(stdout);
      if (!match) {
        log.warn(`Cannot parse WDA build dir from ${_.truncate(stdout, {length: 300})}`);
        return;
      }
      log.debug(`Parsed BUILD_DIR configuration value: '${match[1]}'`);
      // Derived data root is two levels higher over the build dir
      this.derivedDataPath = path.dirname(path.dirname(path.normalize(match[1])));
      log.debug(`Got derived data root: '${this.derivedDataPath}'`);
      return this.derivedDataPath;
    })();
    return await this._derivedDataPathPromise;
  }

  async reset () {
    // if necessary, reset the bundleId to original value
    if (this.realDevice && this.updatedWDABundleId) {
      await resetProjectFile(this.agentPath);
    }
  }

  async prebuild () {
    // first do a build phase
    log.debug('Pre-building WDA before launching test');
    this.usePrebuiltWDA = true;
    await this.start(true);

    this.xcodebuild = null;

    // pause a moment
    await B.delay(this.prebuildDelay);
  }

  async cleanProject () {
    const tmpIsTvOS = isTvOS(this.platformName);
    const libScheme = tmpIsTvOS ? LIB_SCHEME_TV : LIB_SCHEME_IOS;
    const runnerScheme = tmpIsTvOS ? RUNNER_SCHEME_TV : RUNNER_SCHEME_IOS;

    for (const scheme of [libScheme, runnerScheme]) {
      log.debug(`Cleaning the project scheme '${scheme}' to make sure there are no leftovers from previous installs`);
      await exec('xcodebuild', [
        'clean',
        '-project', this.agentPath,
        '-scheme', scheme,
      ]);
    }
  }

  getCommand (buildOnly = false) {
    let cmd = 'xcodebuild';
    let args;

    // figure out the targets for xcodebuild
    const [buildCmd, testCmd] = this.useSimpleBuildTest ? ['build', 'test'] : ['build-for-testing', 'test-without-building'];
    if (buildOnly) {
      args = [buildCmd];
    } else if (this.usePrebuiltWDA || this.useXctestrunFile) {
      args = [testCmd];
    } else {
      args = [buildCmd, testCmd];
    }

    if (this.allowProvisioningDeviceRegistration) {
      // To -allowProvisioningDeviceRegistration flag takes effect, -allowProvisioningUpdates needs to be passed as well.
      args.push('-allowProvisioningUpdates', '-allowProvisioningDeviceRegistration');
    }

    if (this.resultBundlePath) {
      args.push('-resultBundlePath', this.resultBundlePath);
    }

    if (this.resultBundleVersion) {
      args.push('-resultBundleVersion', this.resultBundleVersion);
    }

    if (this.useXctestrunFile) {
      args.push('-xctestrun', this.xctestrunFilePath);
    } else {
      const runnerScheme = isTvOS(this.platformName) ? RUNNER_SCHEME_TV : RUNNER_SCHEME_IOS;
      args.push('-project', this.agentPath, '-scheme', runnerScheme);
      if (this.derivedDataPath) {
        args.push('-derivedDataPath', this.derivedDataPath);
      }
    }
    args.push('-destination', `id=${this.device.udid}`);

    const versionMatch = new RegExp(/^(\d+)\.(\d+)/).exec(this.platformVersion);
    if (versionMatch) {
      args.push(`IPHONEOS_DEPLOYMENT_TARGET=${versionMatch[1]}.${versionMatch[2]}`);
    } else {
      log.warn(`Cannot parse major and minor version numbers from platformVersion "${this.platformVersion}". ` +
        'Will build for the default platform instead');
    }

    if (this.realDevice && this.xcodeConfigFile) {
      log.debug(`Using Xcode configuration file: '${this.xcodeConfigFile}'`);
      args.push('-xcconfig', this.xcodeConfigFile);
    }

    if (!process.env.APPIUM_XCUITEST_TREAT_WARNINGS_AS_ERRORS) {
      // This sometimes helps to survive Xcode updates
      args.push('GCC_TREAT_WARNINGS_AS_ERRORS=0');
    }

    // Below option slightly reduces build time in debug build
    // with preventing to generate `/Index/DataStore` which is used by development
    args.push('COMPILER_INDEX_STORE_ENABLE=NO');

    return {cmd, args};
  }

  async createSubProcess (buildOnly = false) {
    if (!this.useXctestrunFile && this.realDevice) {
      if (this.keychainPath && this.keychainPassword) {
        await setRealDeviceSecurity(this.keychainPath, this.keychainPassword);
      }
      if (this.xcodeOrgId && this.xcodeSigningId && !this.xcodeConfigFile) {
        this.xcodeConfigFile = await generateXcodeConfigFile(this.xcodeOrgId, this.xcodeSigningId);
      }
    }

    const {cmd, args} = this.getCommand(buildOnly);
    log.debug(`Beginning ${buildOnly ? 'build' : 'test'} with command '${cmd} ${args.join(' ')}' ` +
              `in directory '${this.bootstrapPath}'`);
    const env = Object.assign({}, process.env, {
      USE_PORT: this.wdaRemotePort,
      WDA_PRODUCT_BUNDLE_IDENTIFIER: this.updatedWDABundleId || WDA_RUNNER_BUNDLE_ID,
    });
    if (this.mjpegServerPort) {
      // https://github.com/appium/WebDriverAgent/pull/105
      env.MJPEG_SERVER_PORT = this.mjpegServerPort;
    }
    const upgradeTimestamp = await getWDAUpgradeTimestamp(this.bootstrapPath);
    if (upgradeTimestamp) {
      env.UPGRADE_TIMESTAMP = upgradeTimestamp;
    }
    const xcodebuild = new SubProcess(cmd, args, {
      cwd: this.bootstrapPath,
      env,
      detached: true,
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let logXcodeOutput = !!this.showXcodeLog;
    const logMsg = _.isBoolean(this.showXcodeLog)
      ? `Output from xcodebuild ${this.showXcodeLog ? 'will' : 'will not'} be logged`
      : 'Output from xcodebuild will only be logged if any errors are present there';
    log.debug(`${logMsg}. To change this, use 'showXcodeLog' desired capability`);
    xcodebuild.on('output', (stdout, stderr) => {
      let out = stdout || stderr;
      // we want to pull out the log file that is created, and highlight it
      // for diagnostic purposes
      if (out.includes('Writing diagnostic log for test session to')) {
        // pull out the first line that begins with the path separator
        // which *should* be the line indicating the log file generated
        xcodebuild.logLocation = _.first(_.remove(out.trim().split('\n'), (v) => v.startsWith(path.sep)));
        log.debug(`Log file for xcodebuild test: ${xcodebuild.logLocation}`);
      }

      // if we have an error we want to output the logs
      // otherwise the failure is inscrutible
      // but do not log permission errors from trying to write to attachments folder
      const ignoreError = IGNORED_ERRORS.some((x) => out.includes(x));
      if (this.showXcodeLog !== false && out.includes('Error Domain=') && !ignoreError) {
        logXcodeOutput = true;

        // terrible hack to handle case where xcode return 0 but is failing
        xcodebuild._wda_error_occurred = true;
      }

      // do not log permission errors from trying to write to attachments folder
      if (logXcodeOutput && !ignoreError) {
        for (const line of out.split(EOL)) {
          xcodeLog.error(line);
          if (line) {
            xcodebuild._wda_error_message += `${EOL}${line}`;
          }
        }
      }
    });

    return xcodebuild;
  }

  async start (buildOnly = false) {
    this.xcodebuild = await this.createSubProcess(buildOnly);
    // Store xcodebuild message
    this.xcodebuild._wda_error_message = '';

    // wrap the start procedure in a promise so that we can catch, and report,
    // any startup errors that are thrown as events
    return await new B((resolve, reject) => {
      this.xcodebuild.on('exit', async (code, signal) => {
        log.error(`xcodebuild exited with code '${code}' and signal '${signal}'`);
        // print out the xcodebuild file if users have asked for it
        if (this.showXcodeLog && this.xcodebuild.logLocation) {
          xcodeLog.error(`Contents of xcodebuild log file '${this.xcodebuild.logLocation}':`);
          try {
            let data = await fs.readFile(this.xcodebuild.logLocation, 'utf8');
            for (let line of data.split('\n')) {
              xcodeLog.error(line);
            }
          } catch (err) {
            log.error(`Unable to access xcodebuild log file: '${err.message}'`);
          }
        }
        this.xcodebuild.processExited = true;
        if (this.xcodebuild._wda_error_occurred || (!signal && code !== 0)) {
          return reject(new Error(`xcodebuild failed with code ${code}${EOL}` +
            `xcodebuild error message:${EOL}${this.xcodebuild._wda_error_message}`));
        }
        // in the case of just building, the process will exit and that is our finish
        if (buildOnly) {
          return resolve();
        }
      });

      return (async () => {
        try {
          const timer = new timing.Timer().start();
          await this.xcodebuild.start(true);
          if (!buildOnly) {
            let status = await this.waitForStart(timer);
            resolve(status);
          }
        } catch (err) {
          let msg = `Unable to start WebDriverAgent: ${err}`;
          log.error(msg);
          reject(new Error(msg));
        }
      })();
    });
  }

  async waitForStart (timer) {
    // try to connect once every 0.5 seconds, until `launchTimeout` is up
    log.debug(`Waiting up to ${this.launchTimeout}ms for WebDriverAgent to start`);
    let currentStatus = null;
    try {
      let retries = parseInt(this.launchTimeout / 500, 10);
      await retryInterval(retries, 1000, async () => {
        if (this.xcodebuild.processExited) {
          // there has been an error elsewhere and we need to short-circuit
          return;
        }
        const proxyTimeout = this.noSessionProxy.timeout;
        this.noSessionProxy.timeout = 1000;
        try {
          currentStatus = await this.noSessionProxy.command('/status', 'GET');
          if (currentStatus && currentStatus.ios && currentStatus.ios.ip) {
            this.agentUrl = currentStatus.ios.ip;
          }
          log.debug(`WebDriverAgent information:`);
          log.debug(JSON.stringify(currentStatus, null, 2));
        } catch (err) {
          throw new Error(`Unable to connect to running WebDriverAgent: ${err.message}`);
        } finally {
          this.noSessionProxy.timeout = proxyTimeout;
        }
      });

      if (this.xcodebuild.processExited) {
        // there has been an error elsewhere and we need to short-circuit
        return currentStatus;
      }

      log.debug(`WebDriverAgent successfully started after ${timer.getDuration().asMilliSeconds.toFixed(0)}ms`);
    } catch (err) {
      // at this point, if we have not had any errors from xcode itself (reported
      // elsewhere), we can let this go through and try to create the session
      log.debug(err.message);
      log.warn(`Getting status of WebDriverAgent on device timed out. Continuing`);
    }
    return currentStatus;
  }

  async quit () {
    await killProcess('xcodebuild', this.xcodebuild);
  }
}

export { XcodeBuild };
export default XcodeBuild;

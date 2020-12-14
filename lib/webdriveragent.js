import _ from 'lodash';
import path from 'path';
import url from 'url';
import B from 'bluebird';
import { JWProxy } from 'appium-base-driver';
import { fs, util, plist, mkdirp } from 'appium-support';
import log from './logger';
import { NoSessionProxy } from './no-session-proxy';
import {
  getWDAUpgradeTimestamp, resetTestProcesses, getPIDsListeningOnPort
} from './utils';
import XcodeBuild from './xcodebuild';
import AsyncLock from 'async-lock';
import { exec } from 'teen_process';
import { bundleWDASim } from './check-dependencies';
import {
  BOOTSTRAP_PATH, WDA_RUNNER_BUNDLE_ID, WDA_RUNNER_APP,
  WDA_BASE_URL, WDA_UPGRADE_TIMESTAMP_PATH,
} from './constants';

const WDA_LAUNCH_TIMEOUT = 60 * 1000;
const WDA_AGENT_PORT = 8100;
const WDA_CF_BUNDLE_NAME = 'WebDriverAgentRunner-Runner';
const SHARED_RESOURCES_GUARD = new AsyncLock();

class WebDriverAgent {
  constructor (xcodeVersion, args = {}) {
    this.xcodeVersion = xcodeVersion;

    this.args = _.clone(args);

    this.device = args.device;
    this.platformVersion = args.platformVersion;
    this.platformName = args.platformName;
    this.iosSdkVersion = args.iosSdkVersion;
    this.host = args.host;
    this.isRealDevice = !!args.realDevice;
    this.idb = (args.device || {}).idb;
    this.wdaBundlePath = args.wdaBundlePath;

    this.setWDAPaths(args.bootstrapPath, args.agentPath);

    this.wdaLocalPort = args.wdaLocalPort;
    this.wdaRemotePort = args.wdaLocalPort || WDA_AGENT_PORT;
    this.wdaBaseUrl = args.wdaBaseUrl || WDA_BASE_URL;

    this.prebuildWDA = args.prebuildWDA;

    this.webDriverAgentUrl = args.webDriverAgentUrl;

    this.started = false;

    this.wdaConnectionTimeout = args.wdaConnectionTimeout;

    this.useXctestrunFile = args.useXctestrunFile;
    this.usePrebuiltWDA = args.usePrebuiltWDA;
    this.derivedDataPath = args.derivedDataPath;
    this.mjpegServerPort = args.mjpegServerPort;

    this.updatedWDABundleId = args.updatedWDABundleId;

    this.xcodebuild = new XcodeBuild(this.xcodeVersion, this.device, {
      platformVersion: this.platformVersion,
      platformName: this.platformName,
      iosSdkVersion: this.iosSdkVersion,
      agentPath: this.agentPath,
      bootstrapPath: this.bootstrapPath,
      realDevice: this.isRealDevice,
      showXcodeLog: args.showXcodeLog,
      xcodeConfigFile: args.xcodeConfigFile,
      xcodeOrgId: args.xcodeOrgId,
      xcodeSigningId: args.xcodeSigningId,
      keychainPath: args.keychainPath,
      keychainPassword: args.keychainPassword,
      useSimpleBuildTest: args.useSimpleBuildTest,
      usePrebuiltWDA: args.usePrebuiltWDA,
      updatedWDABundleId: this.updatedWDABundleId,
      launchTimeout: args.wdaLaunchTimeout || WDA_LAUNCH_TIMEOUT,
      wdaRemotePort: this.wdaRemotePort,
      useXctestrunFile: this.useXctestrunFile,
      derivedDataPath: args.derivedDataPath,
      mjpegServerPort: this.mjpegServerPort,
      allowProvisioningDeviceRegistration: args.allowProvisioningDeviceRegistration,
      resultBundlePath: args.resultBundlePath,
      resultBundleVersion: args.resultBundleVersion,
    });
  }

  setWDAPaths (bootstrapPath, agentPath) {
    // allow the user to specify a place for WDA. This is undocumented and
    // only here for the purposes of testing development of WDA
    this.bootstrapPath = bootstrapPath || BOOTSTRAP_PATH;
    log.info(`Using WDA path: '${this.bootstrapPath}'`);

    // for backward compatibility we need to be able to specify agentPath too
    this.agentPath = agentPath || path.resolve(this.bootstrapPath, 'WebDriverAgent.xcodeproj');
    log.info(`Using WDA agent: '${this.agentPath}'`);
  }

  async cleanupObsoleteProcesses () {
    const obsoletePids = await getPIDsListeningOnPort(this.url.port,
      (cmdLine) => cmdLine.includes('/WebDriverAgentRunner') &&
        !cmdLine.toLowerCase().includes(this.device.udid.toLowerCase()));

    if (_.isEmpty(obsoletePids)) {
      log.debug(`No obsolete cached processes from previous WDA sessions ` +
        `listening on port ${this.url.port} have been found`);
      return;
    }

    log.info(`Detected ${obsoletePids.length} obsolete cached process${obsoletePids.length === 1 ? '' : 'es'} ` +
      `from previous WDA sessions. Cleaning them up`);
    try {
      await exec('kill', obsoletePids);
    } catch (e) {
      log.warn(`Failed to kill obsolete cached process${obsoletePids.length === 1 ? '' : 'es'} '${obsoletePids}'. ` +
        `Original error: ${e.message}`);
    }
  }

  /**
   * Return boolean if WDA is running or not
   * @return {boolean} True if WDA is running
   * @throws {Error} If there was invalid response code or body
   */
  async isRunning () {
    return !!(await this.getStatus());
  }

  get basePath () {
    if (this.url.path === '/') {
      return '';
    }
    return this.url.path || '';
  }

  /**
   * Return current running WDA's status like below
   * {
   *   "state": "success",
   *   "os": {
   *     "name": "iOS",
   *     "version": "11.4",
   *     "sdkVersion": "11.3"
   *   },
   *   "ios": {
   *     "simulatorVersion": "11.4",
   *     "ip": "172.254.99.34"
   *   },
   *   "build": {
   *     "time": "Jun 24 2018 17:08:21",
   *     "productBundleIdentifier": "com.facebook.WebDriverAgentRunner"
   *   }
   * }
   *
   * @return {?object} State Object
   * @throws {Error} If there was invalid response code or body
   */
  async getStatus () {
    const noSessionProxy = new NoSessionProxy({
      server: this.url.hostname,
      port: this.url.port,
      base: this.basePath,
      timeout: 3000,
    });
    try {
      return await noSessionProxy.command('/status', 'GET');
    } catch (err) {
      log.debug(`WDA is not listening at '${this.url.href}'`);
      return null;
    }
  }

  /**
   * Uninstall WDAs from the test device.
   * Over Xcode 11, multiple WDA can be in the device since Xcode 11 generates different WDA.
   * Appium does not expect multiple WDAs are running on a device.
   */
  async uninstall () {
    try {
      const bundleIds = await this.device.getUserInstalledBundleIdsByBundleName(WDA_CF_BUNDLE_NAME);
      if (_.isEmpty(bundleIds)) {
        log.debug('No WDAs on the device.');
        return;
      }

      log.debug(`Uninstalling WDAs: '${bundleIds}'`);
      for (const bundleId of bundleIds) {
        await this.device.removeApp(bundleId);
      }
    } catch (e) {
      log.debug(e);
      log.warn(`WebDriverAgent uninstall failed. Perhaps, it is already uninstalled? ` +
        `Original error: ${e.message}`);
    }
  }

  async _cleanupProjectIfFresh () {
    const homeFolder = process.env.HOME;
    if (!homeFolder) {
      log.info('The HOME folder path cannot be determined');
      return;
    }

    const currentUpgradeTimestamp = await getWDAUpgradeTimestamp();
    if (!_.isInteger(currentUpgradeTimestamp)) {
      log.info('It is impossible to determine the timestamp of the package');
      return;
    }

    const timestampPath = path.resolve(homeFolder, WDA_UPGRADE_TIMESTAMP_PATH);
    if (await fs.exists(timestampPath)) {
      try {
        await fs.access(timestampPath, fs.W_OK);
      } catch (ign) {
        log.info(`WebDriverAgent upgrade timestamp at '${timestampPath}' is not writeable. ` +
          `Skipping sources cleanup`);
        return;
      }
      const recentUpgradeTimestamp = parseInt(await fs.readFile(timestampPath, 'utf8'), 10);
      if (_.isInteger(recentUpgradeTimestamp)) {
        if (recentUpgradeTimestamp >= currentUpgradeTimestamp) {
          log.info(`WebDriverAgent does not need a cleanup. The sources are up to date ` +
            `(${recentUpgradeTimestamp} >= ${currentUpgradeTimestamp})`);
          return;
        }
        log.info(`WebDriverAgent sources have been upgraded ` +
          `(${recentUpgradeTimestamp} < ${currentUpgradeTimestamp})`);
      } else {
        log.warn(`The recent upgrade timestamp at '${timestampPath}' is corrupted. Trying to fix it`);
      }
    }

    try {
      await mkdirp(path.dirname(timestampPath));
      await fs.writeFile(timestampPath, `${currentUpgradeTimestamp}`, 'utf8');
      log.debug(`Stored the recent WebDriverAgent upgrade timestamp ${currentUpgradeTimestamp} ` +
        `at '${timestampPath}'`);
    } catch (e) {
      log.info(`Unable to create the recent WebDriverAgent upgrade timestamp at '${timestampPath}'. ` +
        `Original error: ${e.message}`);
      return;
    }

    try {
      await this.xcodebuild.cleanProject();
    } catch (e) {
      log.warn(`Cannot perform WebDriverAgent project cleanup. Original error: ${e.message}`);
    }
  }

  /**
   * Return current running WDA's status like below after launching WDA
   * {
   *   "state": "success",
   *   "os": {
   *     "name": "iOS",
   *     "version": "11.4",
   *     "sdkVersion": "11.3"
   *   },
   *   "ios": {
   *     "simulatorVersion": "11.4",
   *     "ip": "172.254.99.34"
   *   },
   *   "build": {
   *     "time": "Jun 24 2018 17:08:21",
   *     "productBundleIdentifier": "com.facebook.WebDriverAgentRunner"
   *   }
   * }
   *
   * @param {string} sessionId Launch WDA and establish the session with this sessionId
   * @return {?object} State Object
   * @throws {Error} If there was invalid response code or body
   */
  async launch (sessionId) {
    if (this.webDriverAgentUrl) {
      log.info(`Using provided WebdriverAgent at '${this.webDriverAgentUrl}'`);
      this.url = this.webDriverAgentUrl;
      this.setupProxies(sessionId);
      return await this.getStatus();
    }

    log.info('Launching WebDriverAgent on the device');

    this.setupProxies(sessionId);

    if (!this.useXctestrunFile && !await fs.exists(this.agentPath)) {
      throw new Error(`Trying to use WebDriverAgent project at '${this.agentPath}' but the ` +
                      'file does not exist');
    }

    // useXctestrunFile and usePrebuiltWDA use existing dependencies
    // It depends on user side
    if (this.idb || this.useXctestrunFile || (this.derivedDataPath && this.usePrebuiltWDA)) {
      log.info('Skipped WDA project cleanup according to the provided capabilities');
    } else {
      const synchronizationKey = path.normalize(this.bootstrapPath);
      await SHARED_RESOURCES_GUARD.acquire(synchronizationKey,
        async () => await this._cleanupProjectIfFresh());
    }

    // We need to provide WDA local port, because it might be occupied
    await resetTestProcesses(this.device.udid, !this.isRealDevice);

    if (this.idb) {
      return await this.startWithIDB();
    }

    await this.xcodebuild.init(this.noSessionProxy);

    // Start the xcodebuild process
    if (this.prebuildWDA) {
      await this.xcodebuild.prebuild();
    }
    return await this.xcodebuild.start();
  }

  async startWithIDB () {
    log.info('Will launch WDA with idb instead of xcodebuild since the corresponding flag is enabled');
    const {wdaBundleId, testBundleId} = await this.prepareWDA();
    const env = {
      USE_PORT: this.wdaRemotePort,
      WDA_PRODUCT_BUNDLE_IDENTIFIER: this.updatedWDABundleId,
    };
    if (this.mjpegServerPort) {
      env.MJPEG_SERVER_PORT = this.mjpegServerPort;
    }

    return await this.idb.runXCUITest(wdaBundleId, wdaBundleId, testBundleId, {env});
  }

  async parseBundleId (wdaBundlePath) {
    const infoPlistPath = path.join(wdaBundlePath, 'Info.plist');
    const infoPlist = await plist.parsePlist(await fs.readFile(infoPlistPath));
    if (!infoPlist.CFBundleIdentifier) {
      throw new Error(`Could not find bundle id in '${infoPlistPath}'`);
    }
    return infoPlist.CFBundleIdentifier;
  }

  async prepareWDA () {
    const wdaBundlePath = this.wdaBundlePath || await this.fetchWDABundle();
    const wdaBundleId = await this.parseBundleId(wdaBundlePath);
    if (!await this.device.isAppInstalled(wdaBundleId)) {
      await this.device.installApp(wdaBundlePath);
    }
    const testBundleId = await this.idb.installXCTestBundle(path.join(wdaBundlePath, 'PlugIns', 'WebDriverAgentRunner.xctest'));
    return {wdaBundleId, testBundleId, wdaBundlePath};
  }

  async fetchWDABundle () {
    if (!this.derivedDataPath) {
      return await bundleWDASim(this.xcodebuild);
    }
    const wdaBundlePaths = await fs.glob(`${this.derivedDataPath}/**/*${WDA_RUNNER_APP}/`, {
      absolute: true,
    });
    if (_.isEmpty(wdaBundlePaths)) {
      throw new Error(`Could not find the WDA bundle in '${this.derivedDataPath}'`);
    }
    return wdaBundlePaths[0];
  }

  async isSourceFresh () {
    const existsPromises = [
      'Resources',
      `Resources${path.sep}WebDriverAgent.bundle`,
    ].map((subPath) => fs.exists(path.resolve(this.bootstrapPath, subPath)));
    return (await B.all(existsPromises)).some((v) => v === false);
  }

  setupProxies (sessionId) {
    const proxyOpts = {
      server: this.url.hostname,
      port: this.url.port,
      base: this.basePath,
      timeout: this.wdaConnectionTimeout,
      keepAlive: true,
    };

    this.jwproxy = new JWProxy(proxyOpts);
    this.jwproxy.sessionId = sessionId;
    this.proxyReqRes = this.jwproxy.proxyReqRes.bind(this.jwproxy);

    this.noSessionProxy = new NoSessionProxy(proxyOpts);
  }

  async quit () {
    log.info('Shutting down sub-processes');

    await this.xcodebuild.quit();
    await this.xcodebuild.reset();

    if (this.jwproxy) {
      this.jwproxy.sessionId = null;
    }

    this.started = false;

    if (!this.args.webDriverAgentUrl) {
      // if we populated the url ourselves (during `setupCaching` call, for instance)
      // then clean that up. If the url was supplied, we want to keep it
      this.webDriverAgentUrl = null;
    }
  }

  get url () {
    if (!this._url) {
      if (this.webDriverAgentUrl) {
        this._url = url.parse(this.webDriverAgentUrl);
      } else {
        const port = this.wdaLocalPort || WDA_AGENT_PORT;
        const {protocol, hostname} = url.parse(this.wdaBaseUrl || WDA_BASE_URL);
        this._url = url.parse(`${protocol}//${hostname}:${port}`);
      }
    }
    return this._url;
  }

  set url (_url) {
    this._url = url.parse(_url);
  }

  get fullyStarted () {
    return this.started;
  }

  set fullyStarted (started = false) {
    this.started = started;
  }

  async retrieveDerivedDataPath () {
    return await this.xcodebuild.retrieveDerivedDataPath();
  }

  /**
   * Reuse running WDA if it has the same bundle id with updatedWDABundleId.
   * Or reuse it if it has the default id without updatedWDABundleId.
   * Uninstall it if the method faces an exception for the above situation.
   *
   * @param {string} updatedWDABundleId BundleId you'd like to use
   */
  async setupCaching () {
    const status = await this.getStatus();
    if (!status || !status.build) {
      log.debug('WDA is currently not running. There is nothing to cache');
      return;
    }

    const {
      productBundleIdentifier,
      upgradedAt,
    } = status.build;
    // for real device
    if (util.hasValue(productBundleIdentifier) && util.hasValue(this.updatedWDABundleId) && this.updatedWDABundleId !== productBundleIdentifier) {
      log.info(`Will uninstall running WDA since it has different bundle id. The actual value is '${productBundleIdentifier}'.`);
      return await this.uninstall();
    }
    // for simulator
    if (util.hasValue(productBundleIdentifier) && !util.hasValue(this.updatedWDABundleId) && WDA_RUNNER_BUNDLE_ID !== productBundleIdentifier) {
      log.info(`Will uninstall running WDA since its bundle id is not equal to the default value ${WDA_RUNNER_BUNDLE_ID}`);
      return await this.uninstall();
    }

    const actualUpgradeTimestamp = await getWDAUpgradeTimestamp();
    log.debug(`Upgrade timestamp of the currently bundled WDA: ${actualUpgradeTimestamp}`);
    log.debug(`Upgrade timestamp of the WDA on the device: ${upgradedAt}`);
    if (actualUpgradeTimestamp && upgradedAt && _.toLower(`${actualUpgradeTimestamp}`) !== _.toLower(`${upgradedAt}`)) {
      log.info('Will uninstall running WDA since it has different version in comparison to the one ' +
        `which is bundled with appium-xcuitest-driver module (${actualUpgradeTimestamp} != ${upgradedAt})`);
      return await this.uninstall();
    }

    const message = util.hasValue(productBundleIdentifier)
      ? `Will reuse previously cached WDA instance at '${this.url.href}' with '${productBundleIdentifier}'`
      : `Will reuse previously cached WDA instance at '${this.url.href}'`;
    log.info(`${message}. Set the wdaLocalPort capability to a value different from ${this.url.port} if this is an undesired behavior.`);
    this.webDriverAgentUrl = this.url.href;
  }

  /**
   * Quit and uninstall running WDA.
   */
  async quitAndUninstall () {
    await this.quit();
    await this.uninstall();
  }
}

export default WebDriverAgent;
export { WebDriverAgent };

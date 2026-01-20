import { waitForCondition } from 'asyncbox';
import _ from 'lodash';
import path from 'node:path';
import url from 'node:url';
import B from 'bluebird';
import { JWProxy } from '@appium/base-driver';
import { fs, util, plist } from '@appium/support';
import type { AppiumLogger, StringRecord } from '@appium/types';
import { log as defaultLogger } from './logger';
import { NoSessionProxy } from './no-session-proxy';
import {
  getWDAUpgradeTimestamp, resetTestProcesses, getPIDsListeningOnPort, BOOTSTRAP_PATH
} from './utils';
import {XcodeBuild} from './xcodebuild';
import AsyncLock from 'async-lock';
import { exec } from 'teen_process';
import { bundleWDASim } from './check-dependencies';
import {
  WDA_RUNNER_BUNDLE_ID, WDA_RUNNER_APP,
  WDA_BASE_URL, WDA_UPGRADE_TIMESTAMP_PATH, DEFAULT_TEST_BUNDLE_SUFFIX
} from './constants';
import {Xctest} from 'appium-ios-device';
import {strongbox} from '@appium/strongbox';
import type { WebDriverAgentArgs, AppleDevice } from './types';

const WDA_LAUNCH_TIMEOUT = 60 * 1000;
const WDA_AGENT_PORT = 8100;
const WDA_CF_BUNDLE_NAME = 'WebDriverAgentRunner-Runner';
const SHARED_RESOURCES_GUARD = new AsyncLock();
const RECENT_MODULE_VERSION_ITEM_NAME = 'recentWdaModuleVersion';

export class WebDriverAgent {
  bootstrapPath: string;
  agentPath: string;
  readonly args: WebDriverAgentArgs;
  private readonly log: AppiumLogger;
  readonly device: AppleDevice;
  readonly platformVersion?: string;
  readonly platformName?: string;
  readonly iosSdkVersion?: string;
  readonly host?: string;
  readonly isRealDevice: boolean;
  private readonly wdaBundlePath?: string;
  private readonly wdaLocalPort?: number;
  readonly wdaRemotePort: number;
  readonly wdaBaseUrl: string;
  readonly wdaBindingIP?: string;
  private readonly prebuildWDA?: boolean;
  webDriverAgentUrl?: string;
  started: boolean;
  private readonly wdaConnectionTimeout?: number;
  private readonly useXctestrunFile?: boolean;
  private readonly usePrebuiltWDA?: boolean;
  private readonly derivedDataPath?: string;
  private readonly mjpegServerPort?: number;
  updatedWDABundleId?: string;
  private readonly wdaLaunchTimeout: number;
  private readonly usePreinstalledWDA?: boolean;
  private xctestApiClient?: Xctest | null;
  private readonly updatedWDABundleIdSuffix: string;
  private _xcodebuild?: XcodeBuild | null;
  noSessionProxy?: NoSessionProxy;
  jwproxy?: JWProxy;
  proxyReqRes?: any;
  private _url?: url.UrlWithStringQuery;

  /**
   * Creates a new WebDriverAgent instance.
   * @param args - Configuration arguments for WebDriverAgent
   * @param log - Optional logger instance
   */
  constructor (args: WebDriverAgentArgs, log: AppiumLogger | null = null) {
    this.args = _.clone(args);
    this.log = log ?? defaultLogger;

    this.device = args.device;
    this.platformVersion = args.platformVersion;
    this.platformName = args.platformName;
    this.iosSdkVersion = args.iosSdkVersion;
    this.host = args.host;
    this.isRealDevice = !!args.realDevice;
    this.wdaBundlePath = args.wdaBundlePath;

    this.setWDAPaths(args.bootstrapPath, args.agentPath);

    this.wdaLocalPort = args.wdaLocalPort;
    this.wdaRemotePort = ((this.isRealDevice ? args.wdaRemotePort : null) ?? args.wdaLocalPort)
      || WDA_AGENT_PORT;
    this.wdaBaseUrl = args.wdaBaseUrl || WDA_BASE_URL;
    this.wdaBindingIP = args.wdaBindingIP;
    this.prebuildWDA = args.prebuildWDA;

    // this.args.webDriverAgentUrl guiarantees the capabilities acually
    // gave 'appium:webDriverAgentUrl' but 'this.webDriverAgentUrl'
    // could be used for caching WDA with xcodebuild.
    this.webDriverAgentUrl = args.webDriverAgentUrl;

    this.started = false;

    this.wdaConnectionTimeout = args.wdaConnectionTimeout;

    this.useXctestrunFile = args.useXctestrunFile;
    this.usePrebuiltWDA = args.usePrebuiltWDA;
    this.derivedDataPath = args.derivedDataPath;
    this.mjpegServerPort = args.mjpegServerPort;

    this.updatedWDABundleId = args.updatedWDABundleId;

    this.wdaLaunchTimeout = args.wdaLaunchTimeout || WDA_LAUNCH_TIMEOUT;
    this.usePreinstalledWDA = args.usePreinstalledWDA;
    this.xctestApiClient = null;
    this.updatedWDABundleIdSuffix = args.updatedWDABundleIdSuffix ?? DEFAULT_TEST_BUNDLE_SUFFIX;

    this._xcodebuild = this.canSkipXcodebuild
    ? null
    : new XcodeBuild(this.device, {
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
        launchTimeout: this.wdaLaunchTimeout,
        wdaRemotePort: this.wdaRemotePort,
        wdaBindingIP: this.wdaBindingIP,
        useXctestrunFile: this.useXctestrunFile,
        derivedDataPath: args.derivedDataPath,
        mjpegServerPort: this.mjpegServerPort,
        allowProvisioningDeviceRegistration: args.allowProvisioningDeviceRegistration,
        resultBundlePath: args.resultBundlePath,
        resultBundleVersion: args.resultBundleVersion,
      }, this.log);
  }

  /**
   * Return true if the session does not need xcodebuild.
   * @returns Whether the session needs/has xcodebuild.
   */
  get canSkipXcodebuild (): boolean {
    // Use this.args.webDriverAgentUrl to guarantee
    // the capabilities set gave the `appium:webDriverAgentUrl`.
    return this.usePreinstalledWDA || !!this.args.webDriverAgentUrl;
  }

  /**
   * Get the xcodebuild instance. Throws if not initialized.
   * @returns The XcodeBuild instance
   * @throws Error if xcodebuild is not available
   */
  get xcodebuild (): XcodeBuild {
    if (!this._xcodebuild) {
      throw new Error('xcodebuild is not available');
    }
    return this._xcodebuild;
  }

  /**
   * Return bundle id for WebDriverAgent to launch the WDA.
   * The primary usage is with 'this.usePreinstalledWDA'.
   * It adds `.xctrunner` as suffix by default but 'this.updatedWDABundleIdSuffix'
   * lets skip it.
   *
   * @returns Bundle ID for Xctest.
   */
  get bundleIdForXctest (): string {
    return `${this.updatedWDABundleId ? this.updatedWDABundleId : WDA_RUNNER_BUNDLE_ID}${this.updatedWDABundleIdSuffix}`;
  }

  /**
   * Cleans up obsolete cached processes from previous WDA sessions
   * that are listening on the same port but belong to different devices.
   */
  async cleanupObsoleteProcesses (): Promise<void> {
    const obsoletePids = await getPIDsListeningOnPort(this.url.port as string,
      (cmdLine) => cmdLine.includes('/WebDriverAgentRunner') &&
        !cmdLine.toLowerCase().includes(this.device.udid.toLowerCase()));

    if (_.isEmpty(obsoletePids)) {
      this.log.debug(`No obsolete cached processes from previous WDA sessions ` +
        `listening on port ${this.url.port} have been found`);
      return;
    }

    this.log.info(`Detected ${obsoletePids.length} obsolete cached process${obsoletePids.length === 1 ? '' : 'es'} ` +
      `from previous WDA sessions. Cleaning them up`);
    try {
      await exec('kill', obsoletePids);
    } catch (e: any) {
      this.log.warn(`Failed to kill obsolete cached process${obsoletePids.length === 1 ? '' : 'es'} '${obsoletePids}'. ` +
        `Original error: ${e.message}`);
    }
  }

  /**
   * Gets the base path for the WebDriverAgent URL.
   * @returns The base path (empty string if root path)
   */
  get basePath (): string {
    if (this.url.path === '/') {
      return '';
    }
    return this.url.path || '';
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
   * @param sessionId Launch WDA and establish the session with this sessionId
   */
  async launch (sessionId: string): Promise<StringRecord | null> {
    if (this.webDriverAgentUrl) {
      this.log.info(`Using provided WebdriverAgent at '${this.webDriverAgentUrl}'`);
      this.url = this.webDriverAgentUrl;
      this.setupProxies(sessionId);
      return await this.getStatus();
    }

    if (this.usePreinstalledWDA) {
      return await this.launchWithPreinstalledWDA(sessionId);
    }

    this.log.info('Launching WebDriverAgent on the device');

    this.setupProxies(sessionId);

    if (!this.useXctestrunFile && !await fs.exists(this.agentPath)) {
      throw new Error(`Trying to use WebDriverAgent project at '${this.agentPath}' but the ` +
                      'file does not exist');
    }

    // useXctestrunFile and usePrebuiltWDA use existing dependencies
    // It depends on user side
    if (this.useXctestrunFile || this.usePrebuiltWDA) {
      this.log.info('Skipped WDA project cleanup according to the provided capabilities');
    } else {
      const synchronizationKey = path.normalize(this.bootstrapPath);
      await SHARED_RESOURCES_GUARD.acquire(synchronizationKey,
        async () => await this._cleanupProjectIfFresh());
    }

    // We need to provide WDA local port, because it might be occupied
    await resetTestProcesses(this.device.udid, !this.isRealDevice);

    if (!this.noSessionProxy) {
      throw new Error('noSessionProxy is not available');
    }
    await this.xcodebuild.init(this.noSessionProxy);

    // Start the xcodebuild process
    if (this.prebuildWDA) {
      await this.xcodebuild.prebuild();
    }
    return await this.xcodebuild.start() as StringRecord | null;
  }

  /**
   * Checks if the WebDriverAgent source is fresh by verifying
   * that required resource files exist.
   * @returns `true` if source is fresh (all required files exist), `false` otherwise
   */
  async isSourceFresh (): Promise<boolean> {
    const existsPromises = [
      'Resources',
      `Resources${path.sep}WebDriverAgent.bundle`,
    ].map((subPath) => fs.exists(path.resolve(this.bootstrapPath, subPath)));
    return (await B.all(existsPromises)).some((v) => v === false);
  }

  private async parseBundleId (wdaBundlePath: string): Promise<string> {
    const infoPlistPath = path.join(wdaBundlePath, 'Info.plist');
    const infoPlist = await plist.parsePlist(await fs.readFile(infoPlistPath));
    if (!infoPlist.CFBundleIdentifier) {
      throw new Error(`Could not find bundle id in '${infoPlistPath}'`);
    }
    return infoPlist.CFBundleIdentifier as string;
  }

  private async fetchWDABundle (): Promise<string> {
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

  private setupProxies (sessionId: string): void {
    const proxyOpts: any = {
      log: this.log,
      server: this.url.hostname ?? undefined,
      port: parseInt(this.url.port ?? '', 10) || undefined,
      base: this.basePath,
      timeout: this.wdaConnectionTimeout,
      keepAlive: true,
      scheme: this.url.protocol ? this.url.protocol.replace(':', '') : 'http',
    };
    if (this.args.reqBasePath) {
      proxyOpts.reqBasePath = this.args.reqBasePath;
    }

    this.jwproxy = new JWProxy(proxyOpts);
    this.jwproxy.sessionId = sessionId;
    this.proxyReqRes = this.jwproxy.proxyReqRes.bind(this.jwproxy);

    this.noSessionProxy = new NoSessionProxy(proxyOpts);
  }

  /**
   * Stops the WebDriverAgent session and cleans up resources.
   * Handles both preinstalled WDA and xcodebuild-based sessions.
   */
  async quit (): Promise<void> {
    if (this.usePreinstalledWDA) {
      this.log.info('Stopping the XCTest session');
      if (this.xctestApiClient) {
        this.xctestApiClient.stop();
        this.xctestApiClient = null;
      } else {
        try {
          await this.device.simctl.terminateApp(this.bundleIdForXctest);
        } catch (e: any) {
          this.log.warn(e.message);
        }
      }
    } else if (!this.args.webDriverAgentUrl) {
      this.log.info('Shutting down sub-processes');
      if (this._xcodebuild) {
        await this.xcodebuild.quit();
      }
    } else {
      this.log.debug('Do not stop xcodebuild nor XCTest session ' +
        'since the WDA session is managed by outside this driver.');
    }

    if (this.jwproxy) {
      this.jwproxy.sessionId = null;
    }

    this.started = false;

    if (!this.args.webDriverAgentUrl) {
      // if we populated the url ourselves (during `setupCaching` call, for instance)
      // then clean that up. If the url was supplied, we want to keep it
      this.webDriverAgentUrl = undefined;
    }
  }

  /**
   * Gets the WebDriverAgent URL.
   * Constructs the URL from webDriverAgentUrl if provided, otherwise
   * builds it from wdaBaseUrl, wdaBindingIP, and wdaLocalPort.
   * @returns The parsed URL object
   */
  get url (): url.UrlWithStringQuery {
    if (!this._url) {
      if (this.webDriverAgentUrl) {
        this._url = url.parse(this.webDriverAgentUrl);
      } else {
        const port = this.wdaLocalPort || WDA_AGENT_PORT;
        const {protocol, hostname} = url.parse(this.wdaBaseUrl || WDA_BASE_URL);
        this._url = url.parse(`${protocol}//${this.wdaBindingIP || hostname}:${port}`);
      }
    }
    return this._url;
  }

  /**
   * Sets the WebDriverAgent URL.
   * @param _url - The URL string to parse and set
   */
  set url (_url: string) {
    this._url = url.parse(_url);
  }

  /**
   * Gets whether WebDriverAgent has fully started.
   * @returns `true` if WDA has started, `false` otherwise
   */
  get fullyStarted (): boolean {
    return this.started;
  }

  /**
   * Sets whether WebDriverAgent has fully started.
   * @param started - `true` if WDA has started, `false` otherwise
   */
  set fullyStarted (started: boolean) {
    this.started = started ?? false;
  }

  /**
   * Retrieves the Xcode derived data path for WebDriverAgent.
   * @returns The derived data path, or `undefined` if xcodebuild is skipped
   */
  async retrieveDerivedDataPath (): Promise<string | undefined> {
    if (this.canSkipXcodebuild) {
      return;
    }
    return await this.xcodebuild.retrieveDerivedDataPath();
  }

  /**
   * Reuse running WDA if it has the same bundle id with updatedWDABundleId.
   * Or reuse it if it has the default id without updatedWDABundleId.
   * Uninstall it if the method faces an exception for the above situation.
   */
  async setupCaching (): Promise<void> {
    const status = await this.getStatus(0);
    if (!status || !status.build) {
      this.log.debug('WDA is currently not running. There is nothing to cache');
      return;
    }

    const {
      productBundleIdentifier,
      upgradedAt,
    } = status.build as any;
    // for real device
    if (util.hasValue(productBundleIdentifier) && util.hasValue(this.updatedWDABundleId) && this.updatedWDABundleId !== productBundleIdentifier) {
      this.log.info(`Will uninstall running WDA since it has different bundle id. The actual value is '${productBundleIdentifier}'.`);
      return await this.uninstall();
    }
    // for simulator
    if (util.hasValue(productBundleIdentifier) && !util.hasValue(this.updatedWDABundleId) && WDA_RUNNER_BUNDLE_ID !== productBundleIdentifier) {
      this.log.info(`Will uninstall running WDA since its bundle id is not equal to the default value ${WDA_RUNNER_BUNDLE_ID}`);
      return await this.uninstall();
    }

    const actualUpgradeTimestamp = await getWDAUpgradeTimestamp();
    this.log.debug(`Upgrade timestamp of the currently bundled WDA: ${actualUpgradeTimestamp}`);
    this.log.debug(`Upgrade timestamp of the WDA on the device: ${upgradedAt}`);
    if (actualUpgradeTimestamp && upgradedAt && _.toLower(`${actualUpgradeTimestamp}`) !== _.toLower(`${upgradedAt}`)) {
      this.log.info('Will uninstall running WDA since it has different version in comparison to the one ' +
        `which is bundled with appium-xcuitest-driver module (${actualUpgradeTimestamp} != ${upgradedAt})`);
      return await this.uninstall();
    }

    const message = util.hasValue(productBundleIdentifier)
      ? `Will reuse previously cached WDA instance at '${this.url.href}' with '${productBundleIdentifier}'`
      : `Will reuse previously cached WDA instance at '${this.url.href}'`;
    this.log.info(`${message}. Set the wdaLocalPort capability to a value different from ${this.url.port} if this is an undesired behavior.`);
    this.webDriverAgentUrl = this.url.href;
  }

  /**
   * Quit and uninstall running WDA.
   */
  async quitAndUninstall (): Promise<void> {
    await this.quit();
    await this.uninstall();
  }

  private setWDAPaths (bootstrapPath?: string, agentPath?: string): void {
    // allow the user to specify a place for WDA. This is undocumented and
    // only here for the purposes of testing development of WDA
    this.bootstrapPath = bootstrapPath || BOOTSTRAP_PATH;
    this.log.info(`Using WDA path: '${this.bootstrapPath}'`);

    // for backward compatibility we need to be able to specify agentPath too
    this.agentPath = agentPath || path.resolve(this.bootstrapPath, 'WebDriverAgent.xcodeproj');
    this.log.info(`Using WDA agent: '${this.agentPath}'`);
  }

  private async isRunning (): Promise<boolean> {
    return !!(await this.getStatus());
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
   * @param timeoutMs If zero or negative, returns immediately. Otherwise, waits up to timeoutMs.
   */
  private async getStatus (timeoutMs: number = 0): Promise<StringRecord | null> {
    const noSessionProxy = new NoSessionProxy({
      server: this.url.hostname ?? undefined,
      port: parseInt(this.url.port ?? '', 10) || undefined,
      base: this.basePath,
      timeout: 3000,
    });

    const sendGetStatus = async () => await noSessionProxy.command('/status', 'GET') as StringRecord;

    if (_.isNil(timeoutMs) || timeoutMs <= 0) {
      try {
        return await sendGetStatus();
      } catch (err: any) {
        this.log.debug(`WDA is not listening at '${this.url.href}'. Original error:: ${err.message}`);
        return null;
      }
    }

    let lastError: any = null;
    let status: StringRecord | null = null;
    try {
      await waitForCondition(async () => {
        try {
          status = await sendGetStatus();
          return true;
        } catch (err) {
          lastError = err;
        }
        return false;
      }, {
        waitMs: timeoutMs,
        intervalMs: 300,
      });
    } catch (err: any) {
      this.log.debug(`Failed to get the status endpoint in ${timeoutMs} ms. ` +
        `The last error while accessing ${this.url.href}: ${lastError}. Original error:: ${err.message}.`);
      throw new Error(`WDA was not ready in ${timeoutMs} ms.`);
    }
    return status;
  }

  /**
   * Uninstall WDAs from the test device.
   * Over Xcode 11, multiple WDA can be in the device since Xcode 11 generates different WDA.
   * Appium does not expect multiple WDAs are running on a device.
   */
  private async uninstall (): Promise<void> {
    try {
      const bundleIds = await this.device.getUserInstalledBundleIdsByBundleName(WDA_CF_BUNDLE_NAME);
      if (_.isEmpty(bundleIds)) {
        this.log.debug('No WDAs on the device.');
        return;
      }

      this.log.debug(`Uninstalling WDAs: '${bundleIds}'`);
      for (const bundleId of bundleIds) {
        await this.device.removeApp(bundleId);
      }
    } catch (e: any) {
      this.log.debug(e);
      this.log.warn(`WebDriverAgent uninstall failed. Perhaps, it is already uninstalled? ` +
        `Original error: ${e.message}`);
    }
  }

  private async _cleanupProjectIfFresh (): Promise<void> {
    if (this.canSkipXcodebuild) {
      return;
    }

    const packageInfo = JSON.parse(await fs.readFile(path.join(BOOTSTRAP_PATH, 'package.json'), 'utf8'));
    const box = strongbox(packageInfo.name);
    let boxItem = box.getItem(RECENT_MODULE_VERSION_ITEM_NAME);
    if (!boxItem) {
      const timestampPath = path.resolve(process.env.HOME ?? '', WDA_UPGRADE_TIMESTAMP_PATH);
      if (await fs.exists(timestampPath)) {
        // TODO: It is probably a bit ugly to hardcode the recent version string,
        // TODO: hovewer it should do the job as a temporary transition trick
        // TODO: to switch from a hardcoded file path to the strongbox usage.
        try {
          boxItem = await box.createItemWithValue(RECENT_MODULE_VERSION_ITEM_NAME, '5.0.0');
        } catch (e: any) {
          this.log.warn(`The actual module version cannot be persisted: ${e.message}`);
          return;
        }
      } else {
        this.log.info('There is no need to perform the project cleanup. A fresh install has been detected');
        try {
          await box.createItemWithValue(RECENT_MODULE_VERSION_ITEM_NAME, packageInfo.version);
        } catch (e: any) {
          this.log.warn(`The actual module version cannot be persisted: ${e.message}`);
        }
        return;
      }
    }

    let recentModuleVersion = await boxItem.read();
    try {
      recentModuleVersion = util.coerceVersion(recentModuleVersion, true);
    } catch (e: any) {
      this.log.warn(`The persisted module version string has been damaged: ${e.message}`);
      this.log.info(`Updating it to '${packageInfo.version}' assuming the project clenup is not needed`);
      await boxItem.write(packageInfo.version);
      return;
    }

    if (util.compareVersions(recentModuleVersion, '>=', packageInfo.version)) {
      this.log.info(
        `WebDriverAgent does not need a cleanup. The project sources are up to date ` +
        `(${recentModuleVersion} >= ${packageInfo.version})`
      );
      return;
    }

    this.log.info(
      `Cleaning up the WebDriverAgent project after the module upgrade has happened ` +
      `(${recentModuleVersion} < ${packageInfo.version})`
    );
    try {
      await this.xcodebuild.cleanProject();
      await boxItem.write(packageInfo.version);
    } catch (e: any) {
      this.log.warn(`Cannot perform WebDriverAgent project cleanup. Original error: ${e.message}`);
    }
  }

  /**
   * Launch WDA with preinstalled package with 'xcrun devicectl device process launch'.
   * The WDA package must be prepared properly like published via
   * https://github.com/appium/WebDriverAgent/releases
   * with proper sign for this case.
   *
   * When we implement launching XCTest service via appium-ios-device,
   * this implementation can be replaced with it.
   *
   * @param opts launching WDA with devicectl command options.
   */
  private async _launchViaDevicectl(opts: {env?: Record<string, string | number>} = {}): Promise<void> {
    const {env} = opts;

    await this.device.devicectl.launchApp(
      this.bundleIdForXctest, { env, terminateExisting: true }
    );
  }

  /**
   * Launch WDA with preinstalled package without xcodebuild.
   * @param sessionId Launch WDA and establish the session with this sessionId
   */
  private async launchWithPreinstalledWDA(sessionId: string): Promise<StringRecord | null> {
    const xctestEnv: Record<string, string | number> = {
      USE_PORT: this.wdaLocalPort || WDA_AGENT_PORT,
      WDA_PRODUCT_BUNDLE_IDENTIFIER: this.bundleIdForXctest
    };
    if (this.mjpegServerPort) {
      xctestEnv.MJPEG_SERVER_PORT = this.mjpegServerPort;
    }
    if (this.wdaBindingIP) {
      xctestEnv.USE_IP = this.wdaBindingIP;
    }
    this.log.info('Launching WebDriverAgent on the device without xcodebuild');
    if (this.isRealDevice) {
      // Current method to launch WDA process can be done via 'xcrun devicectl',
      // but it has limitation about the WDA preinstalled package.
      // https://github.com/appium/appium/issues/19206#issuecomment-2014182674
      if (this.platformVersion && util.compareVersions(this.platformVersion, '>=', '17.0')) {
        await this._launchViaDevicectl({env: xctestEnv});
      } else {
        this.xctestApiClient = new Xctest(this.device.udid, this.bundleIdForXctest, null, {env: xctestEnv});
        await this.xctestApiClient.start();
      }
    } else {
      await this.device.simctl.exec('launch', {
        args: [
          '--terminate-running-process',
          this.device.udid,
          this.bundleIdForXctest,
        ],
        env: xctestEnv,
      });
    }

    this.setupProxies(sessionId);
    let status: StringRecord | null;
    try {
      status = await this.getStatus(this.wdaLaunchTimeout);
    } catch {
      throw new Error(
        `Failed to start the preinstalled WebDriverAgent in ${this.wdaLaunchTimeout} ms. ` +
        `The WebDriverAgent might not be properly built or the device might be locked. ` +
        `The 'appium:wdaLaunchTimeout' capability modifies the timeout.`
      );
    }
    this.started = true;
    return status;
  }
}

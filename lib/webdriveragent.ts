import {waitForCondition} from 'asyncbox';
import path from 'node:path';
import {JWProxy} from '@appium/base-driver';
import {fs, util} from '@appium/support';
import type {AppiumLogger, StringRecord} from '@appium/types';
import {log as defaultLogger} from './logger';
import {NoSessionProxy} from './no-session-proxy';
import {BOOTSTRAP_PATH, getWDAUpgradeTimestamp} from './utils';
import {XcodeBuild} from './xcodebuild';
import AsyncLock from 'async-lock';
import {
  WDA_RUNNER_BUNDLE_ID,
  WDA_BASE_URL,
  WDA_UPGRADE_TIMESTAMP_PATH,
  DEFAULT_TEST_BUNDLE_SUFFIX,
} from './constants';
import {strongbox} from '@appium/strongbox';
import type {
  WebDriverAgentArgs,
  AppleDevice,
  XcodeBuildSettings,
  RetrieveBuildSettingsOptions,
  WdaHostOps,
} from './types';
import {
  createDefaultWdaHostOps,
  createWdaStartupStrategy,
  type WdaStartupStrategy,
  type WdaStartupStrategyContext,
} from './wda-strategies';

const WDA_LAUNCH_TIMEOUT = 60 * 1000;
const WDA_AGENT_PORT = 8100;
const SHARED_RESOURCES_GUARD = new AsyncLock();
const RECENT_MODULE_VERSION_ITEM_NAME = 'recentWdaModuleVersion';
const URL_PROTOCOL_SEPARATOR = '://';

export class WebDriverAgent {
  bootstrapPath!: string;
  agentPath!: string;
  readonly args: WebDriverAgentArgs;
  readonly device: AppleDevice;
  readonly platformVersion?: string;
  readonly platformName?: string;
  readonly iosSdkVersion?: string;
  readonly host?: string;
  readonly isRealDevice: boolean;
  readonly wdaRemotePort: number;
  readonly wdaBaseUrl: string;
  readonly wdaBindingIP?: string;
  webDriverAgentUrl?: string;
  started: boolean;
  updatedWDABundleId?: string;
  noSessionProxy?: NoSessionProxy;
  jwproxy?: JWProxy;
  proxyReqRes?: any;
  private readonly log: AppiumLogger;
  private readonly wdaLocalPort?: number;
  private readonly prebuildWDA?: boolean;
  private readonly wdaConnectionTimeout?: number;
  private readonly useXctestrunFile?: boolean;
  private readonly usePrebuiltWDA?: boolean;
  private readonly mjpegServerPort?: number;
  private readonly maxHttpRequestBodySize?: number;
  private readonly wdaLaunchTimeout: number;
  private readonly usePreinstalledWDA?: boolean;
  private readonly updatedWDABundleIdSuffix: string;
  private readonly hostOps: Required<WdaHostOps>;
  private activeStartupStrategy?: WdaStartupStrategy;
  private _xcodebuild?: XcodeBuild | null;
  private _url?: URL;

  /**
   * Creates a new WebDriverAgent instance.
   * @param args - Configuration arguments for WebDriverAgent
   * @param log - Optional logger instance
   */
  constructor(args: WebDriverAgentArgs, log: AppiumLogger | null = null) {
    this.args = {...args};
    this.log = log ?? defaultLogger;

    this.device = args.device;
    this.platformVersion = args.platformVersion;
    this.platformName = args.platformName;
    this.iosSdkVersion = args.iosSdkVersion;
    this.host = args.host;
    this.isRealDevice = !!args.realDevice;

    this.setWDAPaths(args.bootstrapPath, args.agentPath);

    this.wdaLocalPort = args.wdaLocalPort;
    this.wdaRemotePort =
      ((this.isRealDevice ? args.wdaRemotePort : null) ?? args.wdaLocalPort) || WDA_AGENT_PORT;
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
    this.mjpegServerPort = args.mjpegServerPort;
    this.maxHttpRequestBodySize = args.maxHttpRequestBodySize;

    this.updatedWDABundleId = args.updatedWDABundleId;

    this.wdaLaunchTimeout = args.wdaLaunchTimeout || WDA_LAUNCH_TIMEOUT;
    this.usePreinstalledWDA = args.usePreinstalledWDA;
    this.updatedWDABundleIdSuffix = args.updatedWDABundleIdSuffix ?? DEFAULT_TEST_BUNDLE_SUFFIX;
    const defaultHostOps = createDefaultWdaHostOps();
    this.hostOps = {
      simulator: {
        ...defaultHostOps.simulator,
        ...args.hostOps?.simulator,
      },
      realDevicePreinstalled: {
        ...defaultHostOps.realDevicePreinstalled,
        ...args.hostOps?.realDevicePreinstalled,
      },
      realDeviceXcodebuild: {
        ...defaultHostOps.realDeviceXcodebuild,
        ...args.hostOps?.realDeviceXcodebuild,
      },
    };

    this._xcodebuild = this.canSkipXcodebuild
      ? null
      : new XcodeBuild(
          this.device,
          {
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
            maxHttpRequestBodySize: this.maxHttpRequestBodySize,
            allowProvisioningDeviceRegistration: args.allowProvisioningDeviceRegistration,
            resultBundlePath: args.resultBundlePath,
            resultBundleVersion: args.resultBundleVersion,
          },
          this.log,
        );
  }

  /**
   * Return true if the session does not need xcodebuild.
   * @returns Whether the session needs/has xcodebuild.
   */
  get canSkipXcodebuild(): boolean {
    // Use this.args.webDriverAgentUrl to guarantee
    // the capabilities set gave the `appium:webDriverAgentUrl`.
    return this.usePreinstalledWDA || !!this.args.webDriverAgentUrl;
  }

  /**
   * Get the xcodebuild instance. Throws if not initialized.
   * @returns The XcodeBuild instance
   * @throws Error if xcodebuild is not available
   */
  get xcodebuild(): XcodeBuild {
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
  get bundleIdForXctest(): string {
    return `${this.updatedWDABundleId ? this.updatedWDABundleId : WDA_RUNNER_BUNDLE_ID}${this.updatedWDABundleIdSuffix}`;
  }

  /**
   * Gets the base path for the WebDriverAgent URL.
   * @returns The base path (empty string if root path)
   */
  get basePath(): string {
    if (this.url.pathname === '/') {
      return '';
    }
    return this.url.pathname || '';
  }

  /**
   * Gets the WebDriverAgent URL.
   * Constructs the URL from webDriverAgentUrl if provided, otherwise
   * builds it from wdaBaseUrl, wdaBindingIP, and wdaLocalPort.
   * @returns The parsed URL object
   */
  get url(): URL {
    if (!this._url) {
      if (this.webDriverAgentUrl) {
        this._url = this.toUrl(this.webDriverAgentUrl);
      } else {
        const port = this.wdaLocalPort || WDA_AGENT_PORT;
        const parsedBaseUrl = this.toUrl(this.wdaBaseUrl || WDA_BASE_URL);
        this._url = new URL(
          `${parsedBaseUrl.protocol}//${this.wdaBindingIP || parsedBaseUrl.hostname}:${port}`,
        );
      }
    }
    return this._url;
  }

  /**
   * Gets whether WebDriverAgent has fully started.
   * @returns `true` if WDA has started, `false` otherwise
   */
  get fullyStarted(): boolean {
    return this.started;
  }

  /**
   * Sets whether WebDriverAgent has fully started.
   * @param started - `true` if WDA has started, `false` otherwise
   */
  set fullyStarted(started: boolean) {
    this.started = started ?? false;
  }

  /**
   * Sets the WebDriverAgent URL.
   * @param _url - The URL string to parse and set
   */
  set url(_url: string) {
    this._url = this.toUrl(_url);
  }

  /**
   * Cleans up obsolete cached processes from previous WDA sessions
   * that are listening on the same port but belong to different devices.
   */
  async cleanupObsoleteProcesses(): Promise<void> {
    try {
      await this.hostOps.realDeviceXcodebuild.cleanupObsoleteProcesses?.({
        udid: this.device.udid,
        port: this.url.port as string,
        commandLineIncludes: '/WebDriverAgentRunner',
      });
    } catch (e: any) {
      this.log.warn(`Failed to clean obsolete cached processes. Original error: ${e.message}`);
    }
  }

  /**
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
  async launch(sessionId: string): Promise<StringRecord | null> {
    const startupStrategy = this.createStartupStrategy();
    this.log.info(`Selected '${startupStrategy.name}' WebDriverAgent startup strategy`);
    this.activeStartupStrategy = startupStrategy;
    return await startupStrategy.launch(sessionId);
  }

  /**
   * Checks if the WebDriverAgent source is fresh by verifying
   * that required resource files exist.
   * @returns `true` if source is fresh (all required files exist), `false` otherwise
   */
  async isSourceFresh(): Promise<boolean> {
    const existsPromises = ['Resources', path.join('Resources', 'WebDriverAgent.bundle')].map(
      (subPath) => fs.exists(path.resolve(this.bootstrapPath, subPath)),
    );
    return (await Promise.all(existsPromises)).every((v) => v === true);
  }

  /**
   * Stops the WebDriverAgent session and cleans up resources.
   * Handles both preinstalled WDA and xcodebuild-based sessions.
   */
  async quit(): Promise<void> {
    await (this.activeStartupStrategy ?? this.createStartupStrategy()).quit();

    if (this.jwproxy) {
      this.jwproxy.sessionId = null;
    }

    this.started = false;

    if (!this.args.webDriverAgentUrl) {
      // if we populated the url ourselves (during `setupCaching` call, for instance)
      // then clean that up. If the url was supplied, we want to keep it
      this.webDriverAgentUrl = undefined;
    }
    this.activeStartupStrategy = undefined;
  }

  /**
   * Retrieves Xcode build settings.
   * @param options - Optional scheme, SDK, configuration, or destination
   * @returns Build settings, or `undefined` if xcodebuild is skipped or settings cannot be determined
   */
  async retrieveBuildSettings(
    options?: RetrieveBuildSettingsOptions,
  ): Promise<XcodeBuildSettings | undefined> {
    if (this.canSkipXcodebuild) {
      return;
    }
    return await this.xcodebuild.retrieveBuildSettings(options);
  }

  /**
   * @deprecated Use {@link retrieveBuildSettings} instead. Will be removed in a future release.
   * @returns The derived data path, or `undefined` if xcodebuild is skipped
   */
  async retrieveDerivedDataPath(): Promise<string | undefined> {
    if (this.canSkipXcodebuild) {
      return;
    }
    return await this.xcodebuild.retrieveDerivedDataPath();
  }

  /**
   * Reuse running WDA if it has the same bundle id with updatedWDABundleId.
   * Or reuse it if it has the default id without updatedWDABundleId.
   *
   * @returns The WDA URL used for caching on success, or `undefined` if caching was skipped.
   */
  async setupCaching(): Promise<string | undefined> {
    const status = await this.getStatus(0);
    if (!status || !status.build) {
      this.log.debug('WDA is currently not running. There is nothing to cache');
      return undefined;
    }

    const {productBundleIdentifier, upgradedAt} = status.build as any;
    // for real device
    if (
      util.hasValue(productBundleIdentifier) &&
      util.hasValue(this.updatedWDABundleId) &&
      this.updatedWDABundleId !== productBundleIdentifier
    ) {
      this.log.info(
        `Will not reuse running WDA since it has different bundle id. The actual value is '${productBundleIdentifier}'.`,
      );
      return undefined;
    }
    // for simulator
    if (
      util.hasValue(productBundleIdentifier) &&
      !util.hasValue(this.updatedWDABundleId) &&
      WDA_RUNNER_BUNDLE_ID !== productBundleIdentifier
    ) {
      this.log.info(
        `Will not reuse running WDA since its bundle id is not equal to the default value ${WDA_RUNNER_BUNDLE_ID}`,
      );
      return undefined;
    }

    const actualUpgradeTimestamp = await getWDAUpgradeTimestamp();
    this.log.debug(`Upgrade timestamp of the currently bundled WDA: ${actualUpgradeTimestamp}`);
    this.log.debug(`Upgrade timestamp of the WDA on the device: ${upgradedAt}`);
    if (
      actualUpgradeTimestamp &&
      upgradedAt &&
      `${actualUpgradeTimestamp}`.toLowerCase() !== `${upgradedAt}`.toLowerCase()
    ) {
      this.log.info(
        'Will not reuse running WDA since it has different version in comparison to the one ' +
          `which is bundled with appium-xcuitest-driver module (${actualUpgradeTimestamp} != ${upgradedAt})`,
      );
      return undefined;
    }

    const cachedUrl = this.url.href;
    const message = util.hasValue(productBundleIdentifier)
      ? `Will reuse previously cached WDA instance at '${cachedUrl}' with '${productBundleIdentifier}'`
      : `Will reuse previously cached WDA instance at '${cachedUrl}'`;
    this.log.info(
      `${message}. Set the wdaLocalPort capability to a value different from ${this.url.port} if this is an undesired behavior.`,
    );
    this.webDriverAgentUrl = cachedUrl;
    return cachedUrl;
  }

  private createStartupStrategy(): WdaStartupStrategy {
    const context: WdaStartupStrategyContext = {
      argsWebDriverAgentUrl: this.args.webDriverAgentUrl,
      webDriverAgentUrl: this.webDriverAgentUrl,
      usePreinstalledWDA: this.usePreinstalledWDA,
      useXctestrunFile: this.useXctestrunFile,
      usePrebuiltWDA: this.usePrebuiltWDA,
      prebuildWDA: this.prebuildWDA,
      isRealDevice: this.isRealDevice,
      device: this.device,
      agentPath: this.agentPath,
      bootstrapPath: this.bootstrapPath,
      bundleIdForXctest: this.bundleIdForXctest,
      wdaLocalPort: this.wdaLocalPort,
      wdaRemotePort: this.wdaRemotePort,
      wdaBindingIP: this.wdaBindingIP,
      wdaLaunchTimeout: this.wdaLaunchTimeout,
      mjpegServerPort: this.mjpegServerPort,
      maxHttpRequestBodySize: this.maxHttpRequestBodySize,
      platformName: this.platformName,
      platformVersion: this.platformVersion,
      log: this.log,
      hostOps: this.hostOps,
      setWebDriverAgentUrl: (value) => {
        this.webDriverAgentUrl = value;
      },
      setUrl: (value) => {
        this.url = value;
      },
      setupProxies: (sessionId) => this.setupProxies(sessionId),
      getStatus: async (timeoutMs) => await this.getStatus(timeoutMs),
      cleanupProjectIfFresh: async () => {
        const synchronizationKey = path.normalize(this.bootstrapPath);
        await SHARED_RESOURCES_GUARD.acquire(
          synchronizationKey,
          async () => await this._cleanupProjectIfFresh(),
        );
      },
      xcodebuild: () => this.xcodebuild,
      noSessionProxy: () => {
        if (!this.noSessionProxy) {
          throw new Error('noSessionProxy is not available');
        }
        return this.noSessionProxy;
      },
      setStarted: (started) => {
        this.started = started;
      },
    };
    return createWdaStartupStrategy(context);
  }

  private setupProxies(sessionId: string): void {
    const proxyOpts: any = {
      log: this.log,
      server: this.url.hostname ?? undefined,
      port: parseInt(this.url.port ?? '', 10) || undefined,
      base: this.basePath,
      timeout: this.wdaConnectionTimeout,
      keepAlive: true,
      scheme: this.url.protocol ? this.url.protocol.replace(':', '') : 'http',
      headers: this.args.extraRequestHeaders,
    };
    if (this.args.reqBasePath) {
      proxyOpts.reqBasePath = this.args.reqBasePath;
    }

    this.jwproxy = new JWProxy(proxyOpts);
    this.jwproxy.sessionId = sessionId;
    this.proxyReqRes = this.jwproxy.proxyReqRes.bind(this.jwproxy);

    this.noSessionProxy = new NoSessionProxy(proxyOpts);
  }

  private toUrl(value: string): URL {
    // Treat values without `://` as host/path inputs and normalize to http.
    if (!value.includes(URL_PROTOCOL_SEPARATOR)) {
      return new URL(`http://${value}`);
    }
    try {
      return new URL(value);
    } catch {
      throw new Error(`Invalid URL: ${value}`);
    }
  }

  private setWDAPaths(bootstrapPath?: string, agentPath?: string): void {
    // allow the user to specify a place for WDA. This is undocumented and
    // only here for the purposes of testing development of WDA
    this.bootstrapPath = bootstrapPath || BOOTSTRAP_PATH;
    this.log.info(`Using WDA path: '${this.bootstrapPath}'`);

    // for backward compatibility we need to be able to specify agentPath too
    this.agentPath = agentPath || path.resolve(this.bootstrapPath, 'WebDriverAgent.xcodeproj');
    this.log.info(`Using WDA agent: '${this.agentPath}'`);
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
  private async getStatus(timeoutMs: number = 0): Promise<StringRecord | null> {
    const noSessionProxy = new NoSessionProxy({
      scheme: this.url.protocol ? this.url.protocol.replace(':', '') : 'http',
      server: this.url.hostname ?? undefined,
      port: parseInt(this.url.port ?? '', 10) || undefined,
      base: this.basePath,
      timeout: 3000,
      headers: this.args.extraRequestHeaders,
    });

    const sendGetStatus = async () =>
      (await noSessionProxy.command('/status', 'GET')) as StringRecord;

    if (timeoutMs == null || timeoutMs <= 0) {
      try {
        return await sendGetStatus();
      } catch (err: any) {
        this.log.debug(
          `WDA is not listening at '${this.url.href}'. Original error:: ${err.message}`,
        );
        return null;
      }
    }

    let lastError: any = null;
    let status: StringRecord | null = null;
    try {
      await waitForCondition(
        async () => {
          try {
            status = await sendGetStatus();
            return true;
          } catch (err) {
            lastError = err;
          }
          return false;
        },
        {
          waitMs: timeoutMs,
          intervalMs: 300,
        },
      );
    } catch (err: any) {
      this.log.debug(
        `Failed to get the status endpoint in ${timeoutMs} ms. ` +
          `The last error while accessing ${this.url.href}: ${lastError}. Original error:: ${err.message}.`,
      );
      throw new Error(`WDA was not ready in ${timeoutMs} ms.`, {cause: err});
    }
    return status;
  }

  private async _cleanupProjectIfFresh(): Promise<void> {
    if (this.canSkipXcodebuild) {
      return;
    }

    const packageInfo = JSON.parse(
      await fs.readFile(path.join(BOOTSTRAP_PATH, 'package.json'), 'utf8'),
    );
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
        this.log.info(
          'There is no need to perform the project cleanup. A fresh install has been detected',
        );
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
      this.log.info(
        `Updating it to '${packageInfo.version}' assuming the project clenup is not needed`,
      );
      await boxItem.write(packageInfo.version);
      return;
    }

    if (util.compareVersions(recentModuleVersion, '>=', packageInfo.version)) {
      this.log.info(
        `WebDriverAgent does not need a cleanup. The project sources are up to date ` +
          `(${recentModuleVersion} >= ${packageInfo.version})`,
      );
      return;
    }

    this.log.info(
      `Cleaning up the WebDriverAgent project after the module upgrade has happened ` +
        `(${recentModuleVersion} < ${packageInfo.version})`,
    );
    try {
      await this.xcodebuild.cleanProject();
      await boxItem.write(packageInfo.version);
    } catch (e: any) {
      this.log.warn(`Cannot perform WebDriverAgent project cleanup. Original error: ${e.message}`);
    }
  }
}

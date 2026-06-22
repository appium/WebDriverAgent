import {exec} from 'teen_process';
import {fs} from '@appium/support';
import type {AppiumLogger, StringRecord} from '@appium/types';
import {getPIDsListeningOnPort, resetTestProcesses} from './utils';
import type {NoSessionProxy} from './no-session-proxy';
import type {XcodeBuild} from './xcodebuild';
import type {
  AppleDevice,
  RealDevicePreinstalledHostOps,
  RealDeviceXcodebuildHostOps,
  SimulatorHostOps,
  WdaHostOps,
  WdaLaunchEnvironment,
  WdaStartupStrategyName,
} from './types';

const WDA_AGENT_PORT = 8100;
const HOST_OPS_REQUIRED_MESSAGE =
  'Host operations must be provided to launch or terminate preinstalled WebDriverAgent';

export interface WdaStartupStrategy {
  readonly name: WdaStartupStrategyName;
  launch(sessionId: string): Promise<StringRecord | null>;
  quit(): Promise<void>;
}

export interface WdaStartupStrategyContext {
  readonly argsWebDriverAgentUrl?: string;
  readonly webDriverAgentUrl?: string;
  readonly usePreinstalledWDA?: boolean;
  readonly useXctestrunFile?: boolean;
  readonly usePrebuiltWDA?: boolean;
  readonly prebuildWDA?: boolean;
  readonly isRealDevice: boolean;
  readonly device: AppleDevice;
  readonly agentPath: string;
  readonly bootstrapPath: string;
  readonly bundleIdForXctest: string;
  readonly wdaLocalPort?: number;
  readonly wdaRemotePort: number;
  readonly wdaBindingIP?: string;
  readonly wdaLaunchTimeout: number;
  readonly mjpegServerPort?: number;
  readonly maxHttpRequestBodySize?: number;
  readonly platformName?: string;
  readonly platformVersion?: string;
  readonly log: AppiumLogger;
  readonly hostOps: Required<WdaHostOps>;
  setWebDriverAgentUrl(value?: string): void;
  setUrl(value: string): void;
  setupProxies(sessionId: string): void;
  getStatus(timeoutMs?: number): Promise<StringRecord | null>;
  cleanupProjectIfFresh(): Promise<void>;
  xcodebuild(): XcodeBuild;
  noSessionProxy(): NoSessionProxy;
  setStarted(started: boolean): void;
}

class ExistingWdaUrlStrategy implements WdaStartupStrategy {
  readonly name = 'existing-url' as const;

  constructor(private readonly ctx: WdaStartupStrategyContext) {}

  async launch(sessionId: string): Promise<StringRecord | null> {
    this.ctx.log.info(`Using provided WebdriverAgent at '${this.ctx.webDriverAgentUrl}'`);
    this.ctx.setUrl(this.ctx.webDriverAgentUrl as string);
    this.ctx.setupProxies(sessionId);
    return await this.ctx.getStatus();
  }

  async quit(): Promise<void> {
    this.ctx.log.debug(
      'Stopping neither xcodebuild nor XCTest session since WDA lifecycle is not managed by this driver',
    );
  }
}

class SimulatorWdaStrategy implements WdaStartupStrategy {
  readonly name = 'simulator' as const;

  constructor(private readonly ctx: WdaStartupStrategyContext) {}

  async launch(sessionId: string): Promise<StringRecord | null> {
    if (this.ctx.usePreinstalledWDA) {
      return await launchPreinstalled(this.ctx, this.ctx.hostOps.simulator, sessionId);
    }
    return await launchWithXcodebuild(this.ctx, sessionId);
  }

  async quit(): Promise<void> {
    if (this.ctx.usePreinstalledWDA) {
      await terminatePreinstalled(this.ctx, this.ctx.hostOps.simulator);
      return;
    }
    await quitXcodebuild(this.ctx);
  }
}

class RealDeviceXcodebuildStrategy implements WdaStartupStrategy {
  readonly name = 'real-device-xcodebuild' as const;

  constructor(private readonly ctx: WdaStartupStrategyContext) {}

  async launch(sessionId: string): Promise<StringRecord | null> {
    return await launchWithXcodebuild(this.ctx, sessionId);
  }

  async quit(): Promise<void> {
    await quitXcodebuild(this.ctx);
  }
}

class RealDevicePreinstalledStrategy implements WdaStartupStrategy {
  readonly name = 'real-device-preinstalled' as const;

  constructor(private readonly ctx: WdaStartupStrategyContext) {}

  async launch(sessionId: string): Promise<StringRecord | null> {
    return await launchPreinstalled(this.ctx, this.ctx.hostOps.realDevicePreinstalled, sessionId);
  }

  async quit(): Promise<void> {
    await terminatePreinstalled(this.ctx, this.ctx.hostOps.realDevicePreinstalled);
  }
}

/**
 * Selects the WDA startup strategy for the provided launch arguments.
 */
export function selectWdaStartupStrategyName(args: {
  realDevice?: boolean;
  webDriverAgentUrl?: string;
  usePreinstalledWDA?: boolean;
}): WdaStartupStrategyName {
  if (args.webDriverAgentUrl) {
    return 'existing-url';
  }
  if (!args.realDevice) {
    return 'simulator';
  }
  if (args.usePreinstalledWDA) {
    return 'real-device-preinstalled';
  }
  return 'real-device-xcodebuild';
}

/**
 * Creates a WDA startup strategy for the current facade state.
 */
export function createWdaStartupStrategy(ctx: WdaStartupStrategyContext): WdaStartupStrategy {
  const startupStrategy = selectWdaStartupStrategyName({
    realDevice: ctx.isRealDevice,
    webDriverAgentUrl: ctx.webDriverAgentUrl,
    usePreinstalledWDA: ctx.usePreinstalledWDA,
  });
  switch (startupStrategy) {
    case 'existing-url':
      return new ExistingWdaUrlStrategy(ctx);
    case 'simulator':
      return new SimulatorWdaStrategy(ctx);
    case 'real-device-preinstalled':
      return new RealDevicePreinstalledStrategy(ctx);
    case 'real-device-xcodebuild':
      return new RealDeviceXcodebuildStrategy(ctx);
    default:
      throw new Error(`Unknown WDA startup strategy: ${startupStrategy}`);
  }
}

/**
 * Creates default host operations for flows the package can own directly.
 */
export function createDefaultWdaHostOps(): Required<WdaHostOps> {
  return {
    simulator: createDefaultSimulatorWdaHostOps(),
    realDevicePreinstalled: createDefaultRealDevicePreinstalledHostOps(),
    realDeviceXcodebuild: createDefaultRealDeviceXcodebuildHostOps(),
  };
}

/**
 * Creates default simulator host operations.
 */
export function createDefaultSimulatorWdaHostOps(): SimulatorHostOps {
  return {
    async launchPreinstalled() {
      throw new Error(HOST_OPS_REQUIRED_MESSAGE);
    },
    async terminate() {
      throw new Error(HOST_OPS_REQUIRED_MESSAGE);
    },
    async resetTestProcesses({udid, isSimulator}) {
      await resetTestProcesses(udid, isSimulator);
    },
  };
}

/**
 * Creates default real-device preinstalled host operations.
 */
export function createDefaultRealDevicePreinstalledHostOps(): RealDevicePreinstalledHostOps {
  return {
    async launchPreinstalled() {
      throw new Error(HOST_OPS_REQUIRED_MESSAGE);
    },
    async terminate() {
      throw new Error(HOST_OPS_REQUIRED_MESSAGE);
    },
  };
}

/**
 * Creates default real-device xcodebuild host operations.
 */
export function createDefaultRealDeviceXcodebuildHostOps(): RealDeviceXcodebuildHostOps {
  return {
    async resetTestProcesses({udid, isSimulator}) {
      await resetTestProcesses(udid, isSimulator);
    },
    async cleanupObsoleteProcesses({udid, port, commandLineIncludes}) {
      const obsoletePids = await getPIDsListeningOnPort(
        port,
        (cmdLine) =>
          cmdLine.includes(commandLineIncludes) &&
          !cmdLine.toLowerCase().includes(udid.toLowerCase()),
      );

      if (obsoletePids.length > 0) {
        await exec('kill', obsoletePids);
      }
    },
  };
}

async function launchWithXcodebuild(
  ctx: WdaStartupStrategyContext,
  sessionId: string,
): Promise<StringRecord | null> {
  ctx.log.info('Launching WebDriverAgent on the device');

  ctx.setupProxies(sessionId);

  if (!ctx.useXctestrunFile && !(await fs.exists(ctx.agentPath))) {
    throw new Error(
      `Trying to use WebDriverAgent project at '${ctx.agentPath}' but the ` + 'file does not exist',
    );
  }

  if (ctx.useXctestrunFile || ctx.usePrebuiltWDA) {
    ctx.log.info('Skipped WDA project cleanup according to the provided capabilities');
  } else {
    await ctx.cleanupProjectIfFresh();
  }

  const resetTestProcesses = ctx.isRealDevice
    ? ctx.hostOps.realDeviceXcodebuild.resetTestProcesses
    : ctx.hostOps.simulator.resetTestProcesses;
  await resetTestProcesses?.({
    udid: ctx.device.udid,
    isSimulator: !ctx.isRealDevice,
  });

  const xcodebuild = ctx.xcodebuild();
  await xcodebuild.init(ctx.noSessionProxy());

  if (ctx.prebuildWDA) {
    await xcodebuild.prebuild();
  }
  return (await xcodebuild.start()) as StringRecord | null;
}

async function launchPreinstalled(
  ctx: WdaStartupStrategyContext,
  hostOps: SimulatorHostOps | RealDevicePreinstalledHostOps,
  sessionId: string,
): Promise<StringRecord | null> {
  const xctestEnv = createPreinstalledWdaEnvironment(ctx);
  ctx.log.info('Launching WebDriverAgent on the device without xcodebuild');
  await hostOps.launchPreinstalled({
    udid: ctx.device.udid,
    bundleId: ctx.bundleIdForXctest,
    env: xctestEnv,
    wdaLocalPort: ctx.wdaLocalPort,
    wdaRemotePort: ctx.wdaRemotePort,
    platformName: ctx.platformName,
    platformVersion: ctx.platformVersion,
    timeoutMs: ctx.wdaLaunchTimeout,
  });

  ctx.setupProxies(sessionId);
  let status: StringRecord | null;
  try {
    status = await ctx.getStatus(ctx.wdaLaunchTimeout);
  } catch {
    throw new Error(
      `Failed to start the preinstalled WebDriverAgent in ${ctx.wdaLaunchTimeout} ms. ` +
        `The WebDriverAgent might not be properly built or the device might be locked. ` +
        `The 'appium:wdaLaunchTimeout' capability modifies the timeout.`,
    );
  }
  ctx.setStarted(true);
  return status;
}

async function terminatePreinstalled(
  ctx: WdaStartupStrategyContext,
  hostOps: SimulatorHostOps | RealDevicePreinstalledHostOps,
): Promise<void> {
  ctx.log.info('Stopping the XCTest session');
  try {
    await hostOps.terminate({
      udid: ctx.device.udid,
      bundleId: ctx.bundleIdForXctest,
    });
  } catch (e: any) {
    ctx.log.warn(e.message);
  }
}

async function quitXcodebuild(ctx: WdaStartupStrategyContext): Promise<void> {
  ctx.log.info('Shutting down sub-processes');
  await ctx.xcodebuild().quit();
}

function createPreinstalledWdaEnvironment(ctx: WdaStartupStrategyContext): WdaLaunchEnvironment {
  const xctestEnv: WdaLaunchEnvironment = {
    USE_PORT: ctx.wdaLocalPort || WDA_AGENT_PORT,
    WDA_PRODUCT_BUNDLE_IDENTIFIER: ctx.bundleIdForXctest,
  };
  if (ctx.mjpegServerPort) {
    xctestEnv.MJPEG_SERVER_PORT = ctx.mjpegServerPort;
  }
  if (ctx.wdaBindingIP) {
    xctestEnv.USE_IP = ctx.wdaBindingIP;
  }
  if (ctx.maxHttpRequestBodySize) {
    xctestEnv.MAX_HTTP_REQUEST_BODY_SIZE = ctx.maxHttpRequestBodySize;
  }
  return xctestEnv;
}

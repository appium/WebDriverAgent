import {type HTTPHeaders} from '@appium/types';
import type {Simctl} from 'node-simctl';
import type {Devicectl} from 'node-devicectl';

// WebDriverAgentLib/Utilities/FBSettings.h
export interface WDASettings {
  elementResponseAttribute?: string;
  shouldUseCompactResponses?: boolean;
  mjpegServerScreenshotQuality?: number;
  mjpegServerFramerate?: number;
  screenshotQuality?: number;
  elementResponseAttributes?: string;
  mjpegScalingFactor?: number;
  mjpegFixOrientation?: boolean;
  keyboardAutocorrection?: boolean;
  keyboardPrediction?: boolean;
  customSnapshotTimeout?: number;
  snapshotMaxDepth?: number;
  snapshotMaxChildren?: number;
  useFirstMatch?: boolean;
  boundElementsByIndex?: boolean;
  reduceMotion?: boolean;
  defaultActiveApplication?: string;
  activeAppDetectionPoint?: string;
  defaultAlertAction?: 'accept' | 'dismiss';
  acceptAlertButtonSelector?: string;
  dismissAlertButtonSelector?: string;
  screenshotOrientation?:
    | 'auto'
    | 'portrait'
    | 'portraitUpsideDown'
    | 'landscapeRight'
    | 'landscapeLeft';
  waitForIdleTimeout?: number;
  animationCoolOffTimeout?: number;
  maxTypingFrequency?: number;
  useClearTextShortcut?: boolean;
}

// WebDriverAgentLib/Utilities/FBCapabilities.h
export interface WDACapabilities {
  bundleId?: string;
  initialUrl?: string;
  arguments?: string[];
  environment?: Record<string, string>;
  eventloopIdleDelaySec?: number;
  shouldWaitForQuiescence?: boolean;
  maxTypingFrequency?: number;
  shouldUseSingletonTestManager?: boolean;
  waitForIdleTimeout?: number;
  shouldUseCompactResponses?: number;
  elementResponseFields?: unknown;
  disableAutomaticScreenshots?: boolean;
  shouldTerminateApp?: boolean;
  forceAppLaunch?: boolean;
  useNativeCachingStrategy?: boolean;
  forceSimulatorSoftwareKeyboardPresence?: boolean;
  defaultAlertAction?: 'accept' | 'dismiss';
  appLaunchStateTimeoutSec?: number;
}

export interface WebDriverAgentArgs {
  device: AppleDevice; // Required
  platformVersion?: string;
  platformName?: string;
  iosSdkVersion?: string;
  host?: string;
  realDevice?: boolean;
  wdaBundlePath?: string;
  bootstrapPath?: string;
  agentPath?: string;
  wdaLocalPort?: number;
  wdaRemotePort?: number;
  wdaBaseUrl?: string;
  wdaBindingIP?: string;
  prebuildWDA?: boolean;
  webDriverAgentUrl?: string;
  wdaConnectionTimeout?: number;
  useXctestrunFile?: boolean;
  usePrebuiltWDA?: boolean;
  derivedDataPath?: string;
  mjpegServerPort?: number;
  updatedWDABundleId?: string;
  wdaLaunchTimeout?: number;
  usePreinstalledWDA?: boolean;
  updatedWDABundleIdSuffix?: string;
  showXcodeLog?: boolean;
  xcodeConfigFile?: string;
  xcodeOrgId?: string;
  xcodeSigningId?: string;
  keychainPath?: string;
  keychainPassword?: string;
  useSimpleBuildTest?: boolean;
  allowProvisioningDeviceRegistration?: boolean;
  resultBundlePath?: string;
  resultBundleVersion?: string;
  reqBasePath?: string;
  launchTimeout?: number;
  extraRequestHeaders?: HTTPHeaders;
}

export interface AppleDevice {
  udid: string;
  simctl?: Simctl;
  devicectl?: Devicectl;
}

/**
 * Information of the device under test
 */
export interface DeviceInfo {
  isRealDevice: boolean;
  udid: string;
  platformVersion: string;
  platformName: string;
}

/** Xcode build setting key/value pairs from `xcodebuild -showBuildSettings -json`. */
export type XcodeBuildSettings = Record<string, string>;

/** A single target entry returned by `xcodebuild -showBuildSettings -json`. */
export interface XcodeShowBuildSettingsEntry {
  action: string;
  buildSettings: XcodeBuildSettings;
  target: string;
}

export type WdaScheme =
  | 'WebDriverAgentRunner'
  | 'WebDriverAgentLib'
  | 'WebDriverAgentRunner_tvOS'
  | 'WebDriverAgentLib_tvOS';

export type WdaSdk = 'iphonesimulator' | 'iphoneos' | 'appletvsimulator' | 'appletvos';

export type WdaBuildConfiguration = 'Debug' | 'Release';

/** Options passed to {@link XcodeBuild.retrieveBuildSettings}. */
export interface RetrieveBuildSettingsOptions {
  scheme?: WdaScheme;
  sdk?: WdaSdk;
  configuration?: WdaBuildConfiguration;
  /** `-destination` value (e.g. `id=<udid>` or a full destination specifier). */
  destination?: string;
}

export interface XcodeBuildArgs {
  realDevice: boolean; // Required
  agentPath: string; // Required
  bootstrapPath: string; // Required
  platformVersion?: string;
  platformName?: string;
  iosSdkVersion?: string;
  showXcodeLog?: boolean;
  xcodeConfigFile?: string;
  xcodeOrgId?: string;
  xcodeSigningId?: string;
  keychainPath?: string;
  keychainPassword?: string;
  prebuildWDA?: boolean;
  usePrebuiltWDA?: boolean;
  useSimpleBuildTest?: boolean;
  useXctestrunFile?: boolean;
  launchTimeout?: number;
  wdaRemotePort?: number;
  wdaBindingIP?: string;
  updatedWDABundleId?: string;
  derivedDataPath?: string;
  mjpegServerPort?: number;
  prebuildDelay?: number;
  allowProvisioningDeviceRegistration?: boolean;
  resultBundlePath?: string;
  resultBundleVersion?: string;
  extraRequestHeaders?: HTTPHeaders;
}

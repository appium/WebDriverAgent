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
  useFirstMatch?: boolean;
  boundElementsByIndex?: boolean;
  reduceMotion?: boolean;
  defaultActiveApplication?: string;
  activeAppDetectionPoint?: string;
  includeNonModalElements?: boolean;
  defaultAlertAction?: 'accept' | 'dismiss';
  acceptAlertButtonSelector?: string;
  dismissAlertButtonSelector?: string;
  screenshotOrientation?: 'auto' | 'portrait' | 'portraitUpsideDown' | 'landscapeRight' | 'landscapeLeft'
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
  shouldUseTestManagerForVisibilityDetection?: boolean;
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

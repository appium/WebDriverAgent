import path from 'node:path';

import {fs} from '@appium/support';
import {exec} from 'teen_process';

import {getPlatformSchemeSuffix, isTvOS, isWatchOS, BOOTSTRAP_PATH} from './utils/index.js';
import type {XcodeBuild} from './xcodebuild.js';

/**
 * Ensure simulator WDA is built and return the resulting app bundle path.
 */
export async function bundleWDASim(xcodebuild: XcodeBuild): Promise<string> {
  const platformName = xcodebuild.platformName || '';
  const scheme = `WebDriverAgentRunner${getPlatformSchemeSuffix(platformName)}`;
  const sdk = getSimulatorSdk(platformName);

  const derivedDataPath = await xcodebuild.retrieveDerivedDataPath();
  if (!derivedDataPath) {
    throw new Error('Cannot retrieve the path to the Xcode derived data folder');
  }
  const wdaBundlePath = path.join(derivedDataPath, 'Build', 'Products', `Debug-${sdk}`, `${scheme}-Runner.app`);
  if (await fs.exists(wdaBundlePath)) {
    return wdaBundlePath;
  }
  await buildWDASim(scheme, sdk);
  return wdaBundlePath;
}

/**
 * @returns The simulator SDK name for the given platform.
 */
function getSimulatorSdk(platformName: string): 'iphonesimulator' | 'appletvsimulator' | 'watchsimulator' {
  if (isTvOS(platformName)) {
    return 'appletvsimulator';
  }
  if (isWatchOS(platformName)) {
    return 'watchsimulator';
  }
  return 'iphonesimulator';
}

async function buildWDASim(scheme: string, sdk: string): Promise<void> {
  const args = [
    '-project',
    path.join(BOOTSTRAP_PATH, 'WebDriverAgent.xcodeproj'),
    '-scheme',
    scheme,
    '-sdk',
    sdk,
    'CODE_SIGN_IDENTITY=""',
    'CODE_SIGNING_REQUIRED="NO"',
    'GCC_TREAT_WARNINGS_AS_ERRORS=0',
  ];
  await exec('xcodebuild', args);
}

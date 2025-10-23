import { fs } from '@appium/support';
import { exec } from 'teen_process';
import path from 'node:path';
import {
  WDA_SCHEME, SDK_SIMULATOR, WDA_RUNNER_APP
} from './constants';
import { BOOTSTRAP_PATH } from './utils';
import log from './logger';

async function buildWDASim () {
  const args = [
    '-project', path.join(BOOTSTRAP_PATH, 'WebDriverAgent.xcodeproj'),
    '-scheme', WDA_SCHEME,
    '-sdk', SDK_SIMULATOR,
    'CODE_SIGN_IDENTITY=""',
    'CODE_SIGNING_REQUIRED="NO"',
    'GCC_TREAT_WARNINGS_AS_ERRORS=0',
  ];
  await exec('xcodebuild', args);
}

export async function checkForDependencies () {
  log.debug('Dependencies are up to date');
  return false;
}

/**
 *
 * @param {import('./xcodebuild').XcodeBuild} xcodebuild
 * @returns {Promise<string>}
 */
export async function bundleWDASim (xcodebuild) {
  const derivedDataPath = await xcodebuild.retrieveDerivedDataPath();
  if (!derivedDataPath) {
    throw new Error('Cannot retrieve the path to the Xcode derived data folder');
  }
  const wdaBundlePath = path.join(derivedDataPath, 'Build', 'Products', 'Debug-iphonesimulator', WDA_RUNNER_APP);
  if (await fs.exists(wdaBundlePath)) {
    return wdaBundlePath;
  }
  await buildWDASim();
  return wdaBundlePath;
}

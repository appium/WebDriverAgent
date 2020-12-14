import { fs } from 'appium-support';
import _ from 'lodash';
import { exec } from 'teen_process';
import path from 'path';
import XcodeBuild from './xcodebuild';
import {
  WDA_PROJECT, WDA_SCHEME, SDK_SIMULATOR, WDA_RUNNER_APP
} from './constants';
import log from './logger';

async function buildWDASim () {
  const args = [
    '-project', WDA_PROJECT,
    '-scheme', WDA_SCHEME,
    '-sdk', SDK_SIMULATOR,
    'CODE_SIGN_IDENTITY=""',
    'CODE_SIGNING_REQUIRED="NO"',
    'GCC_TREAT_WARNINGS_AS_ERRORS=0',
  ];
  await exec('xcodebuild', args);
}

// eslint-disable-next-line require-await
async function checkForDependencies () {
  log.debug('Dependencies are up to date');
  return false;
}

async function bundleWDASim (xcodebuild, opts = {}) {
  if (xcodebuild && !_.isFunction(xcodebuild.retrieveDerivedDataPath)) {
    xcodebuild = new XcodeBuild();
    opts = xcodebuild;
  }

  const derivedDataPath = await xcodebuild.retrieveDerivedDataPath();
  const wdaBundlePath = path.join(derivedDataPath, 'Build', 'Products', 'Debug-iphonesimulator', WDA_RUNNER_APP);
  if (await fs.exists(wdaBundlePath)) {
    return wdaBundlePath;
  }
  await checkForDependencies(opts);
  await buildWDASim(xcodebuild, opts);
  return wdaBundlePath;
}

export { checkForDependencies, bundleWDASim };

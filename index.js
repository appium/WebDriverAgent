import * as dependencies from './lib/check-dependencies';
import * as proxies from './lib/no-session-proxy';
import * as driver from './lib/webdriveragent';
import * as constants from './lib/constants';
import * as utils from './lib/utils';
import { asyncify } from 'asyncbox';


const { checkForDependencies, bundleWDASim } = dependencies;
const { NoSessionProxy } = proxies;
const { WebDriverAgent } = driver;
const { WDA_BUNDLE_ID, BOOTSTRAP_PATH, WDA_BASE_URL, WDA_RUNNER_BUNDLE_ID, PROJECT_FILE } = constants;
const { resetTestProcesses } = utils;


// When run as a command line utility, this should check for the dependencies
if (require.main === module) {
  asyncify(checkForDependencies);
}

export {
  WebDriverAgent,
  NoSessionProxy,
  checkForDependencies, bundleWDASim,
  resetTestProcesses,
  BOOTSTRAP_PATH, WDA_BUNDLE_ID,
  WDA_RUNNER_BUNDLE_ID, PROJECT_FILE,
  WDA_BASE_URL,
};

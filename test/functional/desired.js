import _ from 'lodash';
import path from 'path';
import glob from 'glob';
import fs from 'fs';
import { system, util } from 'appium-support';


// translate integer environment variable to a boolean 0=false, !0=true
function checkFeatureInEnv (envArg) {
  let feature = parseInt(process.env[envArg], 10);
  if (isNaN(feature)) {
    feature = process.env[envArg];
  }
  return !!feature;
}

const PLATFORM_VERSION = process.env.PLATFORM_VERSION ? process.env.PLATFORM_VERSION : '11.3';
const LAUNCH_WITH_IDB = process.env.LAUNCH_WITH_IDB;

// If it's real device cloud, don't set a device name. Use dynamic device allocation.
const DEVICE_NAME = process.env.DEVICE_NAME
  ? process.env.DEVICE_NAME
  : process.env.SAUCE_RDC
    ? undefined
    : util.compareVersions(PLATFORM_VERSION, '>=', '13.0') ? 'iPhone 8' : 'iPhone 6';

const SHOW_XCODE_LOG = checkFeatureInEnv('SHOW_XCODE_LOG');
const REAL_DEVICE = checkFeatureInEnv('REAL_DEVICE');
let XCCONFIG_FILE = process.env.XCCONFIG_FILE;
if (REAL_DEVICE && !XCCONFIG_FILE) {
  // no xcconfig file specified, so try to find in the root directory of the package
  // this happens once, at the start of a test run, so using sync method is ok
  let cwd = path.resolve(__dirname, '..', '..', '..');
  let files = glob.sync('*.xcconfig', { cwd });
  if (files.length) {
    XCCONFIG_FILE = path.resolve(cwd, _.first(files));
  }
}

// Had to make these two optional dependencies so the tests
// can still run in linux
let uiCatalogPath;
if (system.isMac() && !process.env.CLOUD) {
  // iOS 13+ need a slightly different app to be able to get the correct automation
  uiCatalogPath = parseInt(PLATFORM_VERSION, 10) >= 13
    ? require('ios-uicatalog').uiKitCatalog.absolute
    : require('ios-uicatalog').uiCatalog.absolute;
}

const apps = {};

const CLOUD = process.env.CLOUD;

if (REAL_DEVICE) {
  if (CLOUD) {
    apps.testAppId = 1;
  } else {
    apps.uiCatalogApp = uiCatalogPath.iphoneos;
  }
} else {
  if (CLOUD) {
    apps.uiCatalogApp = 'http://appium.github.io/appium/assets/UICatalog9.4.app.zip';
    apps.touchIdApp = null; // TODO: Upload this to appium.io
  } else {
    apps.uiCatalogApp = uiCatalogPath.iphonesimulator;
    apps.touchIdApp = path.resolve('.', 'test', 'assets', 'TouchIDExample.app');
  }
}

const REAL_DEVICE_CAPS = REAL_DEVICE ? {
  udid: 'auto',
  xcodeConfigFile: XCCONFIG_FILE,
  webkitResponseTimeout: 30000,
  testobject_app_id: apps.testAppId,
  testobject_api_key: process.env.SAUCE_RDC_ACCESS_KEY,
  testobject_remote_appium_url: process.env.APPIUM_STAGING_URL, // TODO: Once RDC starts supporting this again, re-insert this
} : {};

let GENERIC_CAPS = {
  platformName: 'iOS',
  platformVersion: PLATFORM_VERSION,
  deviceName: DEVICE_NAME,
  automationName: 'XCUITest',
  launchWithIDB: !!LAUNCH_WITH_IDB,
  noReset: true,
  maxTypingFrequency: 30,
  clearSystemFiles: true,
  showXcodeLog: SHOW_XCODE_LOG,
  wdaLaunchTimeout: (60 * 1000 * 4),
  wdaConnectionTimeout: (60 * 1000 * 8),
  useNewWDA: true,
  simulatorStartupTimeout: 240000,
};

if (process.env.CLOUD) {
  GENERIC_CAPS.platformVersion = process.env.CLOUD_PLATFORM_VERSION;
  GENERIC_CAPS.build = process.env.SAUCE_BUILD;
  GENERIC_CAPS.showIOSLog = false;
  GENERIC_CAPS[process.env.APPIUM_BUNDLE_CAP || 'appium-version'] = {'appium-url': 'sauce-storage:appium.zip'};
  // TODO: If it's SAUCE_RDC add the appium staging URL

  // `name` will be set during session initialization
}

// on Travis, when load is high, the app often fails to build,
// and tests fail, so use static one in assets if necessary,
// but prefer to have one build locally
// only do this for sim, since real device one needs to be built with dev creds
if (!REAL_DEVICE && !process.env.CLOUD) {
  // this happens a single time, at load-time for the test suite,
  // so sync method is not overly problematic
  if (!fs.existsSync(apps.uiCatalogApp)) {
    apps.uiCatalogApp = path.resolve('.', 'test', 'assets',
      `${parseInt(PLATFORM_VERSION, 10) >= 13 ? 'UIKitCatalog' : 'UICatalog'}-iphonesimulator.app`);
  }
  if (!fs.existsSync(apps.iosTestApp)) {
    apps.iosTestApp = path.resolve('.', 'test', 'assets', 'TestApp-iphonesimulator.app');
  }
}

const UICATALOG_CAPS = _.defaults({
  app: apps.uiCatalogApp,
}, GENERIC_CAPS, REAL_DEVICE_CAPS);

const UICATALOG_SIM_CAPS = _.defaults({
  app: apps.uiCatalogApp,
}, GENERIC_CAPS);
delete UICATALOG_SIM_CAPS.noReset; // do not want to have no reset on the tests that use this

const W3C_CAPS = {
  capabilities: {
    alwaysMatch: UICATALOG_CAPS,
    firstMatch: [{}],
  }
};

let TVOS_CAPS = _.defaults({
  platformName: 'tvOS',
  bundleId: 'com.apple.TVSettings',
  deviceName: 'Apple TV'
}, GENERIC_CAPS);

export {
  UICATALOG_CAPS, UICATALOG_SIM_CAPS,
  PLATFORM_VERSION, DEVICE_NAME, W3C_CAPS,
  TVOS_CAPS
};

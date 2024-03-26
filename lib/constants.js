import path from 'path';

const DEFAULT_TEST_BUNDLE_SUFFIX = '.xctrunner';
const WDA_RUNNER_BUNDLE_ID = 'com.facebook.WebDriverAgentRunner';
const WDA_RUNNER_BUNDLE_ID_FOR_XCTEST = `${WDA_RUNNER_BUNDLE_ID}${DEFAULT_TEST_BUNDLE_SUFFIX}`;
const WDA_RUNNER_APP = 'WebDriverAgentRunner-Runner.app';
const WDA_SCHEME = 'WebDriverAgentRunner';
const PROJECT_FILE = 'project.pbxproj';
const WDA_BASE_URL = 'http://127.0.0.1';

const PLATFORM_NAME_TVOS = 'tvOS';
const PLATFORM_NAME_IOS = 'iOS';

const SDK_SIMULATOR = 'iphonesimulator';
const SDK_DEVICE = 'iphoneos';

const WDA_UPGRADE_TIMESTAMP_PATH = path.join('.appium', 'webdriveragent', 'upgrade.time');

export {
  WDA_RUNNER_BUNDLE_ID, WDA_RUNNER_APP, PROJECT_FILE,
  WDA_SCHEME, PLATFORM_NAME_TVOS, PLATFORM_NAME_IOS,
  SDK_SIMULATOR, SDK_DEVICE, WDA_BASE_URL, WDA_UPGRADE_TIMESTAMP_PATH,
  WDA_RUNNER_BUNDLE_ID_FOR_XCTEST, DEFAULT_TEST_BUNDLE_SUFFIX
};

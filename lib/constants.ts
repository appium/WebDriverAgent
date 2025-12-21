import path from 'node:path';

export const DEFAULT_TEST_BUNDLE_SUFFIX = '.xctrunner';
export const WDA_RUNNER_BUNDLE_ID = 'com.facebook.WebDriverAgentRunner';
export const WDA_RUNNER_BUNDLE_ID_FOR_XCTEST = `${WDA_RUNNER_BUNDLE_ID}${DEFAULT_TEST_BUNDLE_SUFFIX}`;
export const WDA_RUNNER_APP = 'WebDriverAgentRunner-Runner.app';
export const WDA_SCHEME = 'WebDriverAgentRunner';
export const PROJECT_FILE = 'project.pbxproj';
export const WDA_BASE_URL = 'http://127.0.0.1';

export const PLATFORM_NAME_TVOS = 'tvOS';
export const PLATFORM_NAME_IOS = 'iOS';

export const SDK_SIMULATOR = 'iphonesimulator';
export const SDK_DEVICE = 'iphoneos';

export const WDA_UPGRADE_TIMESTAMP_PATH = path.join('.appium', 'webdriveragent', 'upgrade.time');


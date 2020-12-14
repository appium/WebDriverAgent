import path from 'path';


const BOOTSTRAP_PATH = __dirname.endsWith('build')
  ? path.resolve(__dirname, '..', '..', '..')
  : path.resolve(__dirname, '..', '..');
const WDA_BUNDLE_ID = 'com.apple.test.WebDriverAgentRunner-Runner';
const WDA_PROJECT = path.join(BOOTSTRAP_PATH, 'WebDriverAgent.xcodeproj');
const WDA_SCRIPTS_ROOT = path.join(BOOTSTRAP_PATH, 'Scripts');
const WDA_RUNNER_BUNDLE_ID = 'com.facebook.WebDriverAgentRunner';
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
  BOOTSTRAP_PATH, WDA_BUNDLE_ID,
  WDA_RUNNER_BUNDLE_ID, WDA_RUNNER_APP, PROJECT_FILE,
  WDA_PROJECT, WDA_SCHEME,
  PLATFORM_NAME_TVOS, PLATFORM_NAME_IOS,
  SDK_SIMULATOR, SDK_DEVICE,
  WDA_BASE_URL, WDA_SCRIPTS_ROOT, WDA_UPGRADE_TIMESTAMP_PATH
};

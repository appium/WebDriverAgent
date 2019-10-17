import path from 'path';


const BOOTSTRAP_PATH = __dirname.endsWith('build')
  ? path.resolve(__dirname, '..', '..', '..')
  : path.resolve(__dirname, '..', '..');
const WDA_BUNDLE_ID = 'com.apple.test.WebDriverAgentRunner-Runner';
const WDA_PROJECT = path.join(BOOTSTRAP_PATH, 'WebDriverAgent.xcodeproj');
const WDA_RUNNER_BUNDLE_ID = 'com.facebook.WebDriverAgentRunner';
const WDA_RUNNER_APP = 'WebDriverAgentRunner-Runner.app';
const WDA_SCHEME = 'WebDriverAgentRunner';
const PROJECT_FILE = 'project.pbxproj';

const PLATFORM_NAME_TVOS = 'tvOS';
const PLATFORM_NAME_IOS = 'iOS';

const SDK_SIMULATOR = 'iphonesimulator';
const SDK_DEVICE = 'iphoneos';

const CARTHAGE_ROOT = 'Carthage';


export {
  BOOTSTRAP_PATH, WDA_BUNDLE_ID,
  WDA_RUNNER_BUNDLE_ID, WDA_RUNNER_APP, PROJECT_FILE,
  WDA_PROJECT, WDA_SCHEME,
  PLATFORM_NAME_TVOS, PLATFORM_NAME_IOS,
  SDK_SIMULATOR, SDK_DEVICE,
  CARTHAGE_ROOT,
};

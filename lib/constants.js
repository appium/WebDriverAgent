import path from 'path';


const BOOTSTRAP_PATH = __dirname.endsWith('build')
  ? path.resolve(__dirname, '..', '..', '..')
  : path.resolve(__dirname, '..', '..');
const WDA_BUNDLE_ID = 'com.apple.test.WebDriverAgentRunner-Runner';
const WEBDRIVERAGENT_PROJECT = path.join(BOOTSTRAP_PATH, 'WebDriverAgent.xcodeproj');
const WDA_RUNNER_BUNDLE_ID = 'com.facebook.WebDriverAgentRunner';
const PROJECT_FILE = 'project.pbxproj';

const PLATFORM_NAME_TVOS = 'tvOS';
const PLATFORM_NAME_IOS = 'iOS';


export {
  BOOTSTRAP_PATH, WDA_BUNDLE_ID,
  WDA_RUNNER_BUNDLE_ID, PROJECT_FILE,
  WEBDRIVERAGENT_PROJECT,
  PLATFORM_NAME_TVOS, PLATFORM_NAME_IOS
};

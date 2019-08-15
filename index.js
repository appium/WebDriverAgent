import { fs, logger } from 'appium-support';
import { getDevices } from 'node-simctl';
import { asyncify } from 'asyncbox';
import _ from 'lodash';
import { exec } from 'teen_process';
import path from 'path';
import { EOL } from 'os';
import { fileCompare } from './lib/utils';


const log = logger.getLogger('WebDriverAgent');
const execLogger = {
  // logger that gets rid of empty lines
  logNonEmptyLines (data, fn) {
    data = Buffer.isBuffer(data) ? data.toString() : data;
    for (const line of data.split(EOL)) {
      if (line) {
        fn(line);
      }
    }
  },
  debug (data) {
    this.logNonEmptyLines(data, log.debug.bind(log));
  },
  error (data) {
    this.logNonEmptyLines(data, log.error.bind(log));
  },
};

const IOS = 'iOS';
const TVOS = 'tvOS';

const CARTHAGE_CMD = 'carthage';
const CARTFILE = 'Cartfile.resolved';
const CARTHAGE_ROOT = 'Carthage';

const BOOTSTRAP_PATH = __dirname.endsWith('build')
  ? path.resolve(__dirname, '..')
  : __dirname;
const WDA_BUNDLE_ID = 'com.apple.test.WebDriverAgentRunner-Runner';
const WEBDRIVERAGENT_PROJECT = path.join(BOOTSTRAP_PATH, 'WebDriverAgent.xcodeproj');
const WDA_RUNNER_BUNDLE_ID = 'com.facebook.WebDriverAgentRunner';
const PROJECT_FILE = 'project.pbxproj';

let buildDirPath;

async function hasTvOSSims () {
  const devices = _.flatten(Object.values(await getDevices(null, TVOS)));
  return !_.isEmpty(devices);
}

function getCartfileLocations () {
  const cartfile = path.resolve(BOOTSTRAP_PATH, CARTFILE);
  const installedCartfile = path.resolve(BOOTSTRAP_PATH, CARTHAGE_ROOT, CARTFILE);

  return {
    cartfile,
    installedCartfile,
  };
}

async function needsUpdate (cartfile, installedCartfile) {
  return !await fileCompare(cartfile, installedCartfile);
}

async function fetchDependencies (useSsl = false) {
  log.info('Fetching dependencies');
  if (!await fs.which(CARTHAGE_CMD)) {
    log.errorAndThrow('Please make sure that you have Carthage installed (https://github.com/Carthage/Carthage)');
  }

  // check that the dependencies do not need to be updated
  const {
    cartfile,
    installedCartfile,
  } = getCartfileLocations();

  if (!await needsUpdate(cartfile, installedCartfile)) {
    // files are identical
    log.info('Dependencies up-to-date');
    return false;
  }

  let platforms = [IOS];
  if (await hasTvOSSims()) {
    platforms.push(TVOS);
  } else {
    log.debug('tvOS platform will not be included into Carthage bootstrap, because no Simulator devices have been created for it');
  }

  log.info(`Installing/updating dependencies for platforms ${platforms.map((p) => `'${p}'`).join(', ')}`);

  let args = ['bootstrap'];
  if (useSsl) {
    args.push('--use-ssh');
  }
  args.push('--platform', platforms.join(','));
  try {
    await exec(CARTHAGE_CMD, args, {
      logger: execLogger,
      cwd: BOOTSTRAP_PATH,
    });
  } catch (err) {
    // remove the carthage directory, or else subsequent runs will see it and
    // assume the dependencies are already downloaded
    await fs.rimraf(path.resolve(BOOTSTRAP_PATH, CARTHAGE_ROOT));
    throw err;
  }

  // put the resolved cartfile into the Carthage directory
  await fs.copyFile(cartfile, installedCartfile);

  log.debug(`Finished fetching dependencies`);
  return true;
}

async function buildWDASim () {
  await exec('xcodebuild', ['-project', WEBDRIVERAGENT_PROJECT, '-scheme', 'WebDriverAgentRunner', '-sdk', 'iphonesimulator', 'CODE_SIGN_IDENTITY=""', 'CODE_SIGNING_REQUIRED="NO"']);
}

async function retrieveBuildDir () {
  if (buildDirPath) {
    return buildDirPath;
  }

  const {stdout} = await exec('xcodebuild', ['-project', WEBDRIVERAGENT_PROJECT, '-showBuildSettings']);

  const pattern = /^\s*BUILD_DIR\s+=\s+(\/.*)/m;
  const match = pattern.exec(stdout);
  if (!match) {
    throw new Error(`Cannot parse WDA build dir from ${_.truncate(stdout, {length: 300})}`);
  }
  buildDirPath = match[1];
  log.debug(`Got build folder: '${buildDirPath}'`);
  return buildDirPath;
}

async function checkForDependencies (opts = {}) {
  return await fetchDependencies(opts.useSsl);
}

async function bundleWDASim (opts) {
  const derivedDataPath = await retrieveBuildDir();
  const wdaBundlePath = path.join(derivedDataPath, 'Debug-iphonesimulator', 'WebDriverAgentRunner-Runner.app');
  if (await fs.exists(wdaBundlePath)) {
    return wdaBundlePath;
  }
  await checkForDependencies(opts);
  await buildWDASim();
  return wdaBundlePath;
}

if (require.main === module) {
  asyncify(checkForDependencies);
}

export {
  checkForDependencies, retrieveBuildDir,
  bundleWDASim,
  BOOTSTRAP_PATH, WDA_BUNDLE_ID,
  WDA_RUNNER_BUNDLE_ID, PROJECT_FILE,
};

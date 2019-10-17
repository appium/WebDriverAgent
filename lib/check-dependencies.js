import { fs } from 'appium-support';
import { getDevices } from 'node-simctl';
import _ from 'lodash';
import { exec } from 'teen_process';
import path from 'path';
import { EOL } from 'os';
import { fileCompare } from './utils';
import XcodeBuild from './xcodebuild';
import {
  BOOTSTRAP_PATH, WDA_PROJECT, WDA_SCHEME, CARTHAGE_ROOT, SDK_SIMULATOR,
  WDA_RUNNER_APP,
} from './constants';
import log from './logger';


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
    log.errorAndThrow('Please make sure that you have Carthage installed ' +
                      '(https://github.com/Carthage/Carthage), and that it is ' +
                      'available in the PATH for the environment running Appium');
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

async function checkForDependencies (opts = {}) {
  return await fetchDependencies(opts.useSsl);
}

async function bundleWDASim (opts) {
  const xcodebuild = new XcodeBuild();
  const derivedDataPath = await xcodebuild.retrieveDerivedDataPath();
  const wdaBundlePath = path.join(derivedDataPath, 'Debug-iphonesimulator', WDA_RUNNER_APP);
  if (await fs.exists(wdaBundlePath)) {
    return wdaBundlePath;
  }
  await checkForDependencies(opts);
  await buildWDASim();
  return wdaBundlePath;
}

export { checkForDependencies, bundleWDASim };

import { fs, logger } from 'appium-support';
import { getDevices } from 'node-simctl';
import { asyncify } from 'asyncbox';
import _ from 'lodash';
import { exec } from 'teen_process';
import B from 'bluebird';
import path from 'path';
import fc from 'filecompare';
import { EOL } from 'os';


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
const WDA_RUNNER_BUNDLE_ID = 'com.facebook.WebDriverAgentRunner';
const PROJECT_FILE = 'project.pbxproj';

async function hasTvOSSims () {
  const devices = _.flatten(Object.values(await getDevices(null, TVOS)));
  return !_.isEmpty(devices);
}

function getCartfileLocations () {
  // if this is in the `build` directory, go up one
  const relative = __dirname.endsWith('build') ? '..' : '.';
  const cartfile = path.resolve(__dirname, relative, CARTFILE);
  const installedCartfile = path.resolve(__dirname, relative, CARTHAGE_ROOT, CARTFILE);

  return {
    cartfile,
    installedCartfile,
  };
}

async function needsUpdate (cartfile, installedCartfile) {
  return await new B(function (resolve, reject) {
    // `filecompare` is the best file comparison utility, but does not
    // use Node standards, so we cannot automatically promisify
    try {
      fc(cartfile, installedCartfile, function (isEqual) {
        // need update if they are _not_ equal
        resolve(!isEqual);
      });
    } catch (err) {
      if (err.code === 'ENOENT') {
        // the file does not exist, so we need to update
        return resolve(true);
      }
      // some other sort of error
      reject(err);
    }
  });
}

async function adjustFileSystem () {
  let areDependenciesUpdated = false;
  if (!await fs.hasAccess(`${BOOTSTRAP_PATH}/Resources`)) {
    log.debug('Creating WebDriverAgent resources directory');
    await fs.mkdir(`${BOOTSTRAP_PATH}/Resources`);
    areDependenciesUpdated = true;
  }
  if (!await fs.hasAccess(`${BOOTSTRAP_PATH}/Resources/WebDriverAgent.bundle`)) {
    log.debug('Creating WebDriverAgent resource bundle directory');
    await fs.mkdir(`${BOOTSTRAP_PATH}/Resources/WebDriverAgent.bundle`);
    areDependenciesUpdated = true;
  }
  return areDependenciesUpdated;
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
    args.push('--use-ssl');
  }
  args.push('--platform', platforms.join(','));
  await exec (CARTHAGE_CMD, args, {
    logger: execLogger,
    cwd: path.resolve(__dirname, __dirname.endsWith('build') ? '..' : '.'),
  });

  // put the resolved cartfile into the Carthage directory
  await fs.copyFile(cartfile, installedCartfile);

  log.debug(`Finished fetching dependencies`);
  return true;
}

async function checkForDependencies (opts = {}) {
  return await fetchDependencies(opts.useSsl) && await adjustFileSystem();
}

if (require.main === module) {
  asyncify(checkForDependencies);
}


export {
  checkForDependencies, BOOTSTRAP_PATH, WDA_BUNDLE_ID, WDA_RUNNER_BUNDLE_ID,
  PROJECT_FILE,
};

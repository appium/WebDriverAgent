const path = require('path');
const { asyncify } = require('asyncbox');
const { logger, fs } = require('@appium/support');
const { exec } = require('teen_process');
const xcode = require('appium-xcode');

const LOG = new logger.getLogger('WDABuild');
const ROOT_DIR = path.resolve(__dirname, '..');
const DERIVED_DATA_PATH = `${ROOT_DIR}/wdaBuild`;
const WDA_BUNDLE = 'WebDriverAgentRunner-Runner.app';
const WDA_BUNDLE_PATH = path.join(DERIVED_DATA_PATH, 'Build', 'Products', 'Debug-iphonesimulator');

async function buildWebDriverAgent (xcodeVersion) {
  LOG.info(`Deleting ${DERIVED_DATA_PATH} if exists`);
  if (await fs.exists(DERIVED_DATA_PATH)) {
    await fs.rimraf(DERIVED_DATA_PATH);
  }

  // Get Xcode version
  xcodeVersion = xcodeVersion || await xcode.getVersion();
  LOG.info(`Building WebDriverAgent for iOS for Xcode version '${xcodeVersion}'`);

  // Clean and build
  try {
    await exec('/bin/bash', ['./Scripts/build.sh'], {
      env: {TARGET: 'runner', SDK: 'sim', DERIVED_DATA_PATH},
      cwd: ROOT_DIR
    });
  } catch (e) {
    LOG.error(`===FAILED TO BUILD FOR ${xcodeVersion}`);
    LOG.error(e.stdout);
    LOG.error(e.stderr);
    LOG.error(e.message);
    throw e;
  }

  const zipName = `WebDriverAgentRunner-Runner-Sim-${xcodeVersion}.zip`;
  LOG.info(`Creating ${zipName} which includes ${WDA_BUNDLE}`);
  const appBundleZipPath = path.join(ROOT_DIR, zipName);
  await fs.rimraf(appBundleZipPath);
  LOG.info(`Created './${zipName}'`);
  try {
    await exec('xattr', ['-cr', WDA_BUNDLE], {cwd: WDA_BUNDLE_PATH});
    await exec('zip', ['-r', appBundleZipPath, WDA_BUNDLE], {cwd: WDA_BUNDLE_PATH});
  } catch (e) {
    LOG.error(`===FAILED TO ZIP ARCHIVE`);
    LOG.error(e.stdout);
    LOG.error(e.stderr);
    LOG.error(e.message);
    throw e;
  }
  LOG.info(`Zip bundled at "${appBundleZipPath}"`);
}

if (require.main === module) {
  asyncify(buildWebDriverAgent);
}

module.exports = buildWebDriverAgent;

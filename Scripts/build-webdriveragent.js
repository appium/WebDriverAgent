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

const WDA_BUNDLE_TV = 'WebDriverAgentRunner_tvOS-Runner.app';
const WDA_BUNDLE_TV_PATH = path.join(DERIVED_DATA_PATH, 'Build', 'Products', 'Debug-appletvsimulator');

async function buildWebDriverAgent (xcodeVersion) {
  LOG.info(`Cleaning ${DERIVED_DATA_PATH} if exists`);
  try {
    await exec('xcodebuild', ['clean', '-derivedDataPath', DERIVED_DATA_PATH, '-scheme', 'WebDriverAgentRunner'], {
      cwd: ROOT_DIR
    });
  } catch (ign) {}

  // Get Xcode version
  xcodeVersion = xcodeVersion || await xcode.getVersion();
  LOG.info(`Building WebDriverAgent for iOS using Xcode version '${xcodeVersion}'`);

  // Clean and build
  try {
    await exec('/bin/bash', ['./Scripts/build.sh'], {
      env: {TARGET: process.env.TARGET, SDK: process.env.SDK, DERIVED_DATA_PATH},
      cwd: ROOT_DIR
    });
  } catch (e) {
    LOG.error(`===FAILED TO BUILD FOR ${xcodeVersion}`);
    LOG.error(e.stderr);
    throw e;
  }

  const isTv = process.env.TARGET === 'tv_runner';
  const bundle = isTv ? WDA_BUNDLE_TV : WDA_BUNDLE;
  const bundle_path = isTv ? WDA_BUNDLE_TV_PATH : WDA_BUNDLE_PATH;

  const zipName = `WebDriverAgentRunner-Runner-${process.env.SDK}-${xcodeVersion}.zip`;
  LOG.info(`Creating ${zipName} which includes ${bundle}`);
  const appBundleZipPath = path.join(ROOT_DIR, zipName);
  await fs.rimraf(appBundleZipPath);
  LOG.info(`Created './${zipName}'`);
  try {
    await exec('xattr', ['-cr', bundle], {cwd: bundle_path});
    await exec('zip', ['-qr', appBundleZipPath, bundle], {cwd: bundle_path});
  } catch (e) {
    LOG.error(`===FAILED TO ZIP ARCHIVE`);
    LOG.error(e.stderr);
    throw e;
  }
  LOG.info(`Zip bundled at "${appBundleZipPath}"`);
}

if (require.main === module) {
  asyncify(buildWebDriverAgent);
}

module.exports = buildWebDriverAgent;

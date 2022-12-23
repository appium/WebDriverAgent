const path = require('path');
const { asyncify } = require('asyncbox');
const { logger, fs, zip } = require('@appium/support');
const { exec } = require('teen_process');
const xcode = require('appium-xcode');

const log = new logger.getLogger('WDABuild');
const rootDir = path.resolve(__dirname, '..');
const derivedDataPath = `${rootDir}/wdaBuild`;
const wdaAppBundle = 'WebDriverAgentRunner-Runner.app';
const appBundlePath = path.join(derivedDataPath, 'Build', 'Products', 'Debug-iphonesimulator');

async function buildWebDriverAgent (xcodeVersion) {
  log.info(`Deleting ${derivedDataPath} if exists`);
  if (await fs.exists(derivedDataPath)) {
    await fs.rimraf(derivedDataPath);
  }

  // Get Xcode version
  xcodeVersion = xcodeVersion || await xcode.getVersion();
  log.info(`Building WebDriverAgent for iOS for Xcode version '${xcodeVersion}'`);

  // Clean and build
  try {
    await exec('/bin/bash', ['./Scripts/build.sh'], {
      env: {TARGET: 'runner', SDK: 'sim', DERIVED_DATA_PATH: derivedDataPath},
      cwd: rootDir
    });
  } catch (e) {
    log.error(`===FAILED TO BUILD FOR ${xcodeVersion}`);
    log.error(e.stdout);
    log.error(e.stderr);
    log.error(e.message);
    throw e;
  }

  const zipName = `WebDriverAgentRunner-Runner-Sim-${xcodeVersion}.zip`;
  log.info(`Creating ${zipName} which includes ${wdaAppBundle}`);
  const appBundleZipPath = path.join(rootDir, zipName);
  await fs.rimraf(appBundleZipPath);
  log.info(`Created './${zipName}'`);
  await zip.toArchive(appBundleZipPath, {pattern: '*.app/**', cwd: appBundlePath});
  log.info(`Zip bundled at "${appBundleZipPath}"`);
}

if (require.main === module) {
  asyncify(buildWebDriverAgent);
}

module.exports = buildWebDriverAgent;

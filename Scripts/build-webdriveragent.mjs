import path from 'node:path';
import {fileURLToPath} from 'node:url';

import {logger, fs} from '@appium/support';
import * as xcode from 'appium-xcode';
import {exec} from 'teen_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const isMainModule = process.argv[1] && path.resolve(process.argv[1]) === __filename;

const LOG = new logger.getLogger('WDABuild');
const ROOT_DIR = path.resolve(__dirname, '..');
const DERIVED_DATA_PATH = `${ROOT_DIR}/wdaBuild`;

const BUNDLE_INFO = {
  runner: {bundle: 'WebDriverAgentRunner-Runner.app', productDir: 'Debug-iphonesimulator'},
  tv_runner: {bundle: 'WebDriverAgentRunner_tvOS-Runner.app', productDir: 'Debug-appletvsimulator'},
  watch_runner: {bundle: 'WebDriverAgentRunner_watchOS-Runner.app', productDir: 'Debug-watchsimulator'},
};

const TARGETS = ['runner', 'tv_runner', 'watch_runner'];
const SDKS = ['sim', 'tv_sim', 'watch_sim'];

/**
 * Build WebDriverAgent and pack the app bundle into a zip archive.
 *
 * @param {string} [xcodeVersion] Xcode version to include in archive name.
 */
async function buildWebDriverAgent(xcodeVersion) {
  const target = process.env.TARGET;
  const sdk = process.env.SDK;

  if (!TARGETS.includes(target)) {
    throw Error(`Please set TARGETS environment variable from the supported targets ${JSON.stringify(TARGETS)}`);
  }

  if (!SDKS.includes(sdk)) {
    throw Error(`Please set SDK environment variable from the supported SDKs ${JSON.stringify(SDKS)}`);
  }

  LOG.info(`Cleaning ${DERIVED_DATA_PATH} if exists`);
  try {
    await exec('xcodebuild', ['clean', '-derivedDataPath', DERIVED_DATA_PATH, '-scheme', 'WebDriverAgentRunner'], {
      cwd: ROOT_DIR,
    });
  } catch {}

  // Get Xcode version
  xcodeVersion = xcodeVersion || (await xcode.getVersion());
  LOG.info(`Building WebDriverAgent for iOS using Xcode version '${xcodeVersion}'`);

  // Clean and build
  try {
    await exec('/bin/bash', ['./Scripts/build.sh'], {
      env: {TARGET: target, SDK: sdk, DERIVED_DATA_PATH},
      cwd: ROOT_DIR,
    });
  } catch (e) {
    LOG.error(`===FAILED TO BUILD FOR ${xcodeVersion}`);
    LOG.error(e.stderr);
    throw e;
  }

  const {bundle, productDir} = BUNDLE_INFO[target];
  const bundle_path = path.join(DERIVED_DATA_PATH, 'Build', 'Products', productDir);

  const zipName = `WebDriverAgentRunner-Runner-${sdk}-${xcodeVersion}.zip`;
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

if (isMainModule) {
  try {
    await buildWebDriverAgent();
  } catch (e) {
    LOG.error(e);
    process.exit(1);
  }
}

export default buildWebDriverAgent;

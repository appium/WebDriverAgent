const path = require('path');
const os = require('os');
const { asyncify } = require('asyncbox');
const { logger, fs, mkdirp } = require('appium-support');
const { exec } = require('teen_process');
const xcode = require('appium-xcode');

const log = new logger.getLogger('WDABuild');
const rootDir = path.resolve(__dirname, '..', '..');

async function buildWebDriverAgent (xcodeVersion) {
  // Get Xcode version
  xcodeVersion = xcodeVersion || await xcode.getVersion();
  log.info(`Building bundle for Xcode version '${xcodeVersion}'`);

  // Clear WebDriverAgent from derived data
  const derivedDataPath = path.resolve(os.homedir(), 'Library', 'Developer',
    'Xcode', 'DerivedData');
  log.info(`Clearing contents of '${derivedDataPath}/WebDriverAgent-*'`);
  for (const wdaPath of await fs.glob(`${derivedDataPath}/WebDriverAgent-*`)) {
    await fs.rimraf(wdaPath);
  }

  // Clean and build
  await exec('npx', ['gulp', 'clean:carthage']);
  log.info('Running ./Scripts/build.sh');
  let env = {TARGET: 'runner', SDK: 'sim'};
  try {
    await exec('/bin/bash', ['./Scripts/build.sh'], {env, cwd: rootDir});
  } catch (e) {
    log.error(`===FAILED TO BUILD FOR ${xcodeVersion}`);
    log.error(e.stdout);
    log.error(e.stderr);
    log.error(e.message);
    throw e;
  }

  // Create bundles folder
  await mkdirp('bundles');
  const pathToBundles = path.resolve(rootDir, 'bundles');

  // Start creating zip
  const uncompressedDir = path.resolve(rootDir, 'uncompressed');
  await fs.rimraf(uncompressedDir);
  await mkdirp(uncompressedDir);
  log.info('Creating zip');

  // Move contents of this folder to uncompressed folder
  await exec('rsync', [
    '-av', '.', uncompressedDir,
    '--exclude', 'node_modules',
    '--exclude', 'build',
    '--exclude', 'ci-jobs',
    '--exclude', 'lib',
    '--exclude', 'test',
    '--exclude', 'bundles',
  ], {cwd: rootDir});

  // Move DerivedData/WebDriverAgent-* from Library to uncompressed folder
  const wdaPath = (await fs.glob(`${derivedDataPath}/WebDriverAgent-*`))[0];
  await mkdirp(path.resolve(uncompressedDir, 'DerivedData'));
  await fs.rename(wdaPath, path.resolve(uncompressedDir, 'DerivedData', 'WebDriverAgent'));

  // Compress bundle as a tarball
  const pathToZip = path.resolve(pathToBundles, `webdriveragent-xcode_${xcodeVersion}.zip`);
  env = {COPYFILE_DISABLE: 1};
  //await exec('zip', ['-czf', pathToZip, '-C', uncompressedDir, '.'], {env, cwd: rootDir});
  await exec('zip', ['-r', pathToZip, uncompressedDir], {env});
  log.info(`Zip bundled at "${pathToZip}"`);

  // Zip the .app to the root of the project so it gets published in NPM
  const wdaAppBundle = 'WebDriverAgentRunner-Runner.app';
  const appBundlePath = path.join(uncompressedDir, 'DerivedData', 'WebDriverAgent',
    'Build', 'Products', 'Debug-iphonesimulator', wdaAppBundle);
  const zipPath = path.join(rootDir, `${wdaAppBundle}.zip`);
  await fs.rimraf(zipPath);
  log.info(`Created './${wdaAppBundle}.zip'`);
  await exec('zip', ['-r', zipPath, appBundlePath], {env});
  log.info(`Zip bundled at "${zipPath}"`);

  // Clean up the uncompressed directory
  await fs.rimraf(uncompressedDir);
}

if (require.main === module) {
  asyncify(buildWebDriverAgent);
}

module.exports = buildWebDriverAgent;

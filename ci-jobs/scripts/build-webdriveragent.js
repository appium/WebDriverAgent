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

  // Clean and build
  await exec('npx', ['gulp', 'clean:carthage']);
  log.info('Running ./Scripts/build.sh');
  let env = {TARGET: 'runner', SDK: 'sim'};
  await exec('/bin/bash', ['./Scripts/build.sh'], {env, cwd: rootDir});

  // Create bundles folder
  await mkdirp('bundles');
  const pathToBundles = path.resolve(rootDir, 'bundles');

  // Start creating tarball
  const uncompressedDir = path.resolve(rootDir, 'uncompressed');
  await fs.rimraf(uncompressedDir);
  await mkdirp(uncompressedDir);
  log.info('Creating tarball');

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

  // Moved DerivedData/WebDriverAgent-* from Library to uncompressed folder
  const derivedDataPath = path.resolve(os.homedir(), 'Library', 'Developer', 'Xcode', 'DerivedData');
  const wdaPath = (await fs.glob(`${derivedDataPath}/WebDriverAgent-*`))[0];
  await mkdirp(path.resolve(uncompressedDir, 'DerivedData'));
  await fs.rename(wdaPath, path.resolve(uncompressedDir, 'DerivedData', 'WebDriverAgent'));

  // Compress the tarball
  const pathToTar = path.resolve(pathToBundles, `webdriveragent-xcode_${xcodeVersion}.tar.gz`);
  env = {COPYFILE_DISABLE: 1};
  await exec('tar', ['-czf', pathToTar, '-C', uncompressedDir, '.'], {env, cwd: rootDir});
  await fs.rimraf(uncompressedDir);
  log.info(`Tarball bundled at "${pathToTar}"`);
}

if (require.main === module) {
  asyncify(buildWebDriverAgent);
}

module.exports = buildWebDriverAgent;

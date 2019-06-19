const path = require('path');
const os = require('os');
const { asyncify } = require('asyncbox');
const { logger, fs, mkdirp } = require('appium-support');
const { exec } = require('teen_process');
const xcode = require('appium-xcode');

const log = new logger.getLogger('WDABuild');

async function buildWebDriverAgent (xcodeVersion) {
  // Get Xcode version
  xcodeVersion = xcodeVersion || await xcode.getVersion();
  log.info(`Building bundle for Xcode version '${xcodeVersion}'`);

  // Clean and build
  await exec('npx', ['gulp', 'clean:carthage']);
  log.info('Running ./Scripts/build.sh');
  await exec('./Scripts/build.sh');

  // Create tarball using NPM Pack and move to '/bundles' folder
  const pathToBundles = path.resolve('bundles');
  const pathToTar = path.resolve(pathToBundles, `webdriveragent-xcode_${xcodeVersion}.tar.gz`);
  log.info('Running "npm pack" to bundle tarball');
  await mkdirp('bundles');
  await exec('npm', ['pack']);
  const originalPathToTar = (await fs.glob(path.resolve('.', 'appium-webdriveragent-*.tgz')))[0];
  fs.rename(originalPathToTar, pathToTar);

  // Uncompress the tarball
  await exec('tar', ['xvzf', pathToTar, '-C', pathToBundles]);
  const uncompressedDir = path.resolve(pathToBundles, 'package');

  // Add DerivedData to it
  const derivedDataPath = path.resolve(os.homedir(), 'Library', 'Developer', 'Xcode', 'DerivedData');
  const wdaPath = (await fs.glob(`${derivedDataPath}/WebDriverAgent-*`))[0];
  await mkdirp(path.resolve(uncompressedDir, 'DerivedData'));
  await fs.rename(wdaPath, path.resolve(uncompressedDir, 'DerivedData', 'WebDriverAgent'));

  // Re-compress the tarball
  await exec('tar', ['-cvjf', pathToTar, '-C', uncompressedDir, '.']);
  await fs.rimraf(uncompressedDir);
  log.info(`Tarball bundled at "${pathToTar}"`);
}

if (require.main === module) {
  asyncify(buildWebDriverAgent);
}

module.exports = buildWebDriverAgent;

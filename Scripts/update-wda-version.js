const {plist} = require('@appium/support');
const path = require('node:path');
const semver = require('semver');
const log = require('fancy-log');

/**
 * @param {string} argName
 * @returns {string|null}
 */
function parseArgValue (argName) {
  const argNamePattern = new RegExp(`^--${argName}\\b`);
  for (let i = 1; i < process.argv.length; ++i) {
    const arg = process.argv[i];
    if (argNamePattern.test(arg)) {
      return arg.includes('=') ? arg.split('=')[1] : process.argv[i + 1];
    }
  }
  return null;
}

async function updateWdaVersion() {
  const newVersion = parseArgValue('package-version');
  if (!newVersion) {
    throw new Error('No package version argument (use `--package-version=xxx`)');
  }
  if (!semver.valid(newVersion)) {
    throw new Error(
      `Invalid version specified '${newVersion}'. Version should be in the form '1.2.3'`
    );
  }

  const runnerManifest = path.resolve('WebDriverAgentLib', 'Info.plist');
  log.info(`Updating the WebDriverAgent manifest at '${runnerManifest}' to version '${newVersion}'`);
  await plist.updatePlistFile(runnerManifest, {
    CFBundleShortVersionString: newVersion,
    CFBundleVersion: newVersion,
  }, false);
}

(async () => await updateWdaVersion())();

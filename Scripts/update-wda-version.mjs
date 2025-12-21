import {plist, logger} from '@appium/support';
import path from 'node:path';
import semver from 'semver';

const log = logger.getLogger('Versioner');

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

  const libManifest = path.resolve('WebDriverAgentLib', 'Info.plist');
  log.info(`Updating the WebDriverAgent manifest at '${libManifest}' to version '${newVersion}'`);
  await plist.updatePlistFile(libManifest, {
    CFBundleShortVersionString: newVersion,
    CFBundleVersion: newVersion,
  }, false);
}

(async () => await updateWdaVersion())();


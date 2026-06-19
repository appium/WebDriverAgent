import {fs, util} from '@appium/support';
import path, {dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import _fs from 'node:fs';

// Get current filename - works in both CommonJS and ESM
const currentFilename =
  typeof __filename !== 'undefined'
    ? __filename
    : fileURLToPath(new Function('return import.meta.url')());

const currentDirname = dirname(currentFilename);

/**
 * Calculates the path to the current module's root folder
 *
 * @returns {string} The full path to module root
 * @throws {Error} If the current module root folder cannot be determined
 */
const getModuleRoot = util.memoize(function getModuleRoot(): string {
  let currentDir = currentDirname;
  let isAtFsRoot = false;
  while (!isAtFsRoot) {
    const manifestPath = path.join(currentDir, 'package.json');
    try {
      if (
        _fs.existsSync(manifestPath) &&
        JSON.parse(_fs.readFileSync(manifestPath, 'utf8')).name === 'appium-webdriveragent'
      ) {
        return currentDir;
      }
    } catch {}
    currentDir = path.dirname(currentDir);
    isAtFsRoot = currentDir.length <= path.dirname(currentDir).length;
  }
  throw new Error('Cannot find the root folder of the appium-webdriveragent Node.js module');
});

export const BOOTSTRAP_PATH = getModuleRoot();

/**
 * Retrieves WDA upgrade timestamp. The manifest only gets modified on package upgrade.
 */
export async function getWDAUpgradeTimestamp(): Promise<number | null> {
  const packageManifest = path.resolve(getModuleRoot(), 'package.json');
  if (!(await fs.exists(packageManifest))) {
    return null;
  }
  const {mtime} = await fs.stat(packageManifest);
  return mtime.getTime();
}

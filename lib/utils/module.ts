import {fs, node as supportNode} from '@appium/support';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

// Get current filename - works in both CommonJS and ESM
const currentFilename =
  typeof __filename !== 'undefined'
    ? __filename
    : fileURLToPath(new Function('return import.meta.url')());

const moduleRoot = supportNode.getModuleRootSync('appium-webdriveragent', currentFilename);

if (!moduleRoot) {
  throw new Error('Cannot find the root folder of the appium-webdriveragent Node.js module');
}

export const BOOTSTRAP_PATH = moduleRoot;

/**
 * Retrieves WDA upgrade timestamp. The manifest only gets modified on package upgrade.
 */
export async function getWDAUpgradeTimestamp(): Promise<number | null> {
  const packageManifest = path.resolve(BOOTSTRAP_PATH, 'package.json');
  if (!(await fs.exists(packageManifest))) {
    return null;
  }
  const {mtime} = await fs.stat(packageManifest);
  return mtime.getTime();
}

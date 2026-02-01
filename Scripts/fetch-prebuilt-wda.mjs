import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFileSync } from 'node:fs';
import axios from 'axios';
import { logger, fs, mkdirp, net } from '@appium/support';
import _ from 'lodash';
import B from 'bluebird';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const isMainModule = process.argv[1] && path.resolve(process.argv[1]) === __filename;

const log = logger.getLogger('WDA');

async function fetchPrebuiltWebDriverAgentAssets () {
  const packageJson = JSON.parse(readFileSync(path.resolve(__dirname, '..', 'package.json'), 'utf8'));
  const tag = packageJson.version;
  log.info(`Getting links to webdriveragent release ${tag}`);
  const downloadUrl = `https://api.github.com/repos/appium/webdriveragent/releases/tags/v${tag}`;
  log.info(`Getting WDA release ${downloadUrl}`);
  let releases;
  try {
    releases = (await axios({
      url: downloadUrl,
      headers: {
        'user-agent': 'appium',
        'accept': 'application/json, */*',
      },
    })).data;
  } catch (e) {
    throw new Error(`Could not fetch endpoint ${downloadUrl}. Reason: ${e.message}`);
  }

  const webdriveragentsDir = path.resolve(__dirname, '..', 'prebuilt-agents');
  log.info(`Creating webdriveragents directory at: ${webdriveragentsDir}`);
  await fs.rimraf(webdriveragentsDir);
  await mkdirp(webdriveragentsDir);

  // Define a method that does a streaming download of an asset
  async function downloadAgent (url, targetPath) {
    try {
      await net.downloadFile(url, targetPath);
    } catch (err) {
      throw new Error(`Problem downloading webdriveragent from url ${url}: ${err.message}`);
    }
  }

  log.info(`Downloading assets to: ${webdriveragentsDir}`);
  const agentsDownloading = [];
  for (const asset of releases.assets) {
    const url = asset.browser_download_url;
    log.info(`Downloading: ${url}`);
    try {
      const nameOfAgent = _.last(url.split('/'));
      agentsDownloading.push(downloadAgent(url, path.join(webdriveragentsDir, nameOfAgent)));
    } catch { }
  }

  // Wait for them all to finish
  return await B.all(agentsDownloading);
}

if (isMainModule) {
  fetchPrebuiltWebDriverAgentAssets().catch((e) => {
    log.error(e);
    process.exit(1);
  });
}

export default fetchPrebuiltWebDriverAgentAssets;


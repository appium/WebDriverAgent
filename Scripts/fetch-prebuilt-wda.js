const path = require('path');
const request = require('request-promise');
const requestCallback = require('request');
const { asyncify } = require('asyncbox');
const { logger, fs, mkdirp } = require('appium-support');
const _ = require('lodash');
const _fs = require('fs');
const B = require('bluebird');

const log = logger.getLogger('WDA');

async function fetchPrebuiltWebDriverAgentAssets () {
  const tag = require('../package.json').version;
  log.info(`Getting links to webdriveragent release ${tag}`);
  const downloadUrl = `https://api.github.com/repos/appium/webdriveragent/releases/tags/v${tag}`;
  log.info(`Getting WDA release ${downloadUrl}`);
  let releases;
  try {
    releases = await request.get(downloadUrl, {
      headers: {
        'user-agent': 'appium',
      },
      json: true,
    });
  } catch (e) {
    throw new Error(`Could not fetch endpoint '${downloadUrl}. Reason: ${e.message}'`);
  }

  const webdriveragentsDir = path.resolve(__dirname, '..', 'prebuilt-agents');
  log.info(`Creating webdriveragents directory at: ${webdriveragentsDir}`);
  await fs.rimraf(webdriveragentsDir);
  await mkdirp(webdriveragentsDir);

  // Define a method that does a streaming download of an asset
  async function downloadAgent (url, targetPath) {
    try {
      // don't use request-promise here, we need streams
      return await new B((resolve, reject) => {
        requestCallback(url)
          .on('error', reject) // handle real errors, like connection errors
          .on('response', (res) => {
            // handle responses that fail, like 404s
            if (res.statusCode >= 400) {
              return reject(new Error(`${res.statusCode} - ${res.statusMessage}`));
            }
          })
          .pipe(_fs.createWriteStream(targetPath))
          .on('close', resolve);
      });
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
    } catch (ign) { }
  }

  // Wait for them all to finish
  return await B.all(agentsDownloading);
}

if (require.main === module) {
  asyncify(fetchPrebuiltWebDriverAgentAssets);
}

module.exports = fetchPrebuiltWebDriverAgentAssets;

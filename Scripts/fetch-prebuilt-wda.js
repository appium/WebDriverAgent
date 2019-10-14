const path = require('path');
const request = require('request-promise');
const { asyncify } = require('asyncbox');
const { logger, fs, mkdirp } = require('appium-support');
const { exec } = require('teen_process');

const log = logger.getLogger('WDA');

async function fetchPrebuiltWebDriverAgentAssets () {
  const tag = require('../package.json').version;
  const downloadUrl = `https://api.github.com/repos/appium/webdriveragent/releases/tags/v${tag}`;
  log.info(`Getting WDA release ${downloadUrl}`);
  const releases = await request.get(downloadUrl, {
    headers: {
      'user-agent': 'node.js',
    },
    json: true,
  });
  const webdriveragentsDir = path.resolve(__dirname, '..', 'webdriveragents');
  log.info(`Downloading assets to: ${webdriveragentsDir}`);
  await fs.rimraf(webdriveragentsDir);
  await mkdirp(webdriveragentsDir);
  for (const asset of releases.assets) {
    const url = asset.browser_download_url;
    log.info(`Downloading: ${url}`);
    // wget never seems to exit successfully so just ignore non-zero status code
    try {
      await exec('wget', [url, '.'], {cwd: webdriveragentsDir});
    } catch (ign) { }
  }
}

if (require.main === module) {
  asyncify(fetchPrebuiltWebDriverAgentAssets);
}

module.exports = fetchPrebuiltWebDriverAgentAssets;

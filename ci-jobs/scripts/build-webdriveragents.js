const buildWebDriverAgent = require('./build-webdriveragent');
const { asyncify } = require('asyncbox');
const { fs, logger } = require('appium-support');
const { exec } = require('teen_process');

const log = new logger.getLogger('WDA Build');

async function buildAndUploadWebDriverAgents () {
  // Get all xcode paths from /Applications/
  const xcodePaths = (await fs.readdir('/Applications/'))
    .filter((file) => file.toLowerCase().startsWith('xcode_'));

  // Determine which xcodes need to be skipped
  let excludedXcodeArr = (process.env.EXCLUDE_XCODE || '').split(',');
  log.info(`Will skip xcode versions: '${excludedXcodeArr}'`)

  for (let xcodePath of xcodePaths) {
    if (xcodePath.includes('_beta')) {
      continue;
    }
    // Build webdriveragent for this xcode version
    log.info(`Running xcode-select for '${xcodePath}'`);
    await exec('sudo', ['xcode-select', '-s', `/Applications/${xcodePath}/Contents/Developer`]);
    const xcodeVersion = xcodePath.replace('.app', '').split('_', 2)[1];

    if (excludedXcodeArr.includes(xcodeVersion)) {
      log.info(`Skipping xcode version '${xcodeVersion}'`);
      continue;
    }

    log.info('Building webdriveragent for xcode version', xcodeVersion);
    await buildWebDriverAgent(xcodeVersion);
  }

  // Divider log line
  log.info('\n');
}

if (require.main === module) {
  asyncify(buildAndUploadWebDriverAgents);
}

module.exports = buildAndUploadWebDriverAgents;

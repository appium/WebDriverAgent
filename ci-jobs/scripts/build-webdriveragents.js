const buildWebDriverAgent = require('./build-webdriveragent');
const { asyncify } = require('asyncbox');
const { fs, logger } = require('appium-support');
const { exec } = require('teen_process');
const path = require('path');

const log = new logger.getLogger('WDABuild');

async function buildAndUploadWebDriverAgents () {
  // Get all xcode paths from /Applications/
  const xcodePaths = (await fs.readdir('/Applications/'))
    .filter((file) => file.toLowerCase().startsWith('xcode_'));

  // Determine which xcodes need to be skipped
  let excludedXcodeArr = (process.env.EXCLUDE_XCODE || '').replace(/\s/g, '').split(',');
  log.info(`Will skip xcode versions: '${excludedXcodeArr}'`);

  for (let xcodePath of xcodePaths) {
    if (xcodePath.includes('beta')) {
      log.info(`Skipping beta Xcode '${xcodePath}'`);
      continue;
    }

    // Skip if .0 because redundant (example: skip 11.4.0 because it already does 11.4)
    const [, , patch] = xcodePath.split('.');
    if (patch === '0') {
      log.info(`Skipping xcode '${xcodePath}'`);
      continue;
    }

    // Build webdriveragent for this xcode version
    log.info(`Running xcode-select for '${xcodePath}'`);
    await exec('sudo', ['xcode-select', '-s', `/Applications/${xcodePath}/Contents/Developer`]);
    const xcodeVersion = path.parse(xcodePath).name.split('_', 2)[1];

    if (excludedXcodeArr.includes(xcodeVersion)) {
      log.info(`Skipping xcode version '${xcodeVersion}'`);
      continue;
    }

    log.info('Building webdriveragent for xcode version', xcodeVersion);
    try {
      await buildWebDriverAgent(xcodeVersion);
    } catch (e) {
      log.error(`Skipping build for '${xcodeVersion} due to error: ${e}'`);
    }
  }

  // Divider log line
  log.info('\n');
}

if (require.main === module) {
  asyncify(buildAndUploadWebDriverAgents);
}

module.exports = buildAndUploadWebDriverAgents;

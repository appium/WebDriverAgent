import wd from 'wd';
import { startServer } from '../../..';
import { util } from 'appium-support';
import _ from 'lodash';
import axios from 'axios';


const {SAUCE_RDC, SAUCE_EMUSIM, CLOUD} = process.env;

function getPort () {
  if (SAUCE_EMUSIM || SAUCE_RDC) {
    return 80;
  }
  return 4994;
}

function getHost () {
  if (SAUCE_RDC) {
    return 'appium.staging.testobject.org';
  } else if (SAUCE_EMUSIM) {
    return 'ondemand.saucelabs.com';
  }

  return process.env.REAL_DEVICE ? util.localIp() : 'localhost';
}

const HOST = getHost();
const PORT = getPort();
// on CI the timeout needs to be long, mostly so WDA can be built the first time
const MOCHA_TIMEOUT = 60 * 1000 * 4;
const WDA_PORT = 8200;

let driver, server;

if (CLOUD) {
  before(function () {
    process.env.SAUCE_JOB_NAME = `${process.env.TRAVIS_JOB_NUMBER || 'Suite'}: ${this.test.parent.suites[0].title}`;
  });

  // on Sauce Labs we need to track the status of the job
  afterEach(function () {
    if (driver) {
      let fullTitle;
      if (!driver.name) {
        // traverse the title tree to get the whole thing
        let titles = [];
        const currentTest = this.currentTest;
        titles.push(currentTest.title);
        let parent = currentTest.parent;
        while (parent) {
          if (parent.title) {
            titles.push(parent.title);
          }
          parent = parent.parent;
        }
        fullTitle = titles.reverse().join('/');

        // construct the name for the job
        driver.name = `${process.env.TRAVIS_JOB_NUMBER || 'Suite'}: ${_.first(titles)}`;
      }

      // check for the first failure
      if (!driver.errored && this.currentTest.state !== 'passed') {
        // add the first failed job title to the name of the job
        driver.name += ` (${fullTitle})`;
        // and fail the whole job
        driver.errored = true;
      }
    }

    // wd puts info into the error object that mocha can't display easily
    if (this.currentTest.err) {
      console.error('ERROR:', JSON.stringify(this.currentTest.err, null, 2)); // eslint-disable-line
    }
  });
}

async function initDriver () { // eslint-disable-line require-await
  const config = {host: HOST, port: PORT};
  driver = CLOUD
    ? await wd.promiseChainRemote(config, process.env.SAUCE_USERNAME, process.env.SAUCE_ACCESS_KEY)
    : await wd.promiseChainRemote(config);
  driver.name = undefined;
  driver.errored = false;
  return driver;
}

async function initServer () {
  server = await startServer(PORT, HOST);
}

function getServer () {
  return server;
}

async function initWDA (caps) {
  // first, see if this is necessary
  try {
    await axios({url: `http://${HOST}:${WDA_PORT}/status`, timeout: 5000});
  } catch (err) {
    // easiest way to initialize WDA is to go through a test startup
    // otherwise every change to the system would require a change here
    const desiredCaps = Object.assign({
      autoLaunch: false,
      wdaLocalPort: WDA_PORT,
    }, caps);
    await driver.init(desiredCaps);
    await driver.quit();
  }
}

async function initSession (caps) {
  if (!CLOUD) {
    await initServer();
  }

  if (CLOUD) {
    // on cloud tests, we want to set the `name` capability
    if (!caps.name) {
      caps.name = process.env.SAUCE_JOB_NAME || process.env.TRAVIS_JOB_NUMBER || 'unnamed';
    }
  }

  await initDriver();

  if (process.env.USE_WEBDRIVERAGENTURL) {
    await initWDA(caps);
    caps = Object.assign({
      webDriverAgentUrl: `http://${HOST}:${WDA_PORT}`,
      wdaLocalPort: WDA_PORT,
    }, caps);
  }

  const serverRes = await driver.init(caps);
  if (!caps.udid && !caps.fullReset && serverRes[1].udid) {
    caps.udid = serverRes[1].udid;
  }

  return driver;
}

async function deleteSession () {
  try {
    if (CLOUD) {
      await driver.sauceJobUpdate({
        name: driver.name,
        passed: !driver.errored,
      });
    }
  } catch (ign) {}

  try {
    await driver.quit();
  } catch (ign) {
  } finally {
    driver = undefined;
  }

  try {
    await server.close();
  } catch (ign) {}
}

export { initDriver, initSession, deleteSession, getServer, HOST, PORT, MOCHA_TIMEOUT };

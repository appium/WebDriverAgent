import Simctl from 'node-simctl';
import { getVersion } from 'appium-xcode';
import { getSimulator } from 'appium-ios-simulator';
import { killAllSimulators, shutdownSimulator } from './helpers/simulator';
import { SubProcess } from 'teen_process';
import { PLATFORM_VERSION, DEVICE_NAME } from './desired';
import { retryInterval } from 'asyncbox';
import { WebDriverAgent } from '../../lib/webdriveragent';
import axios from 'axios';

const MOCHA_TIMEOUT_MS = 60 * 1000 * 5;

const SIM_DEVICE_NAME = 'webDriverAgentTest';
const SIM_STARTUP_TIMEOUT_MS = MOCHA_TIMEOUT_MS;

let testUrl = 'http://localhost:8100/tree';

function getStartOpts (device) {
  return {
    device,
    platformVersion: PLATFORM_VERSION,
    host: 'localhost',
    port: 8100,
    realDevice: false,
    showXcodeLog: true,
    wdaLaunchTimeout: 60 * 3 * 1000,
  };
}


describe('WebDriverAgent', function () {
  this.timeout(MOCHA_TIMEOUT_MS);
  let chai;
  let xcodeVersion;

  before(async function () {
    chai = await import('chai');
    const chaiAsPromised = await import('chai-as-promised');

    chai.should();
    chai.use(chaiAsPromised.default);

    // Don't do these tests on Sauce Labs
    if (process.env.CLOUD) {
      this.skip();
    }

    xcodeVersion = await getVersion(true);
  });
  describe('with fresh sim', function () {
    let device;
    let simctl;

    before(async function () {
      simctl = new Simctl();
      simctl.udid = await simctl.createDevice(
        SIM_DEVICE_NAME,
        DEVICE_NAME,
        PLATFORM_VERSION
      );
      device = await getSimulator(simctl.udid);

      // Prebuild WDA
      const wda = new WebDriverAgent(xcodeVersion, {
        iosSdkVersion: PLATFORM_VERSION,
        platformVersion: PLATFORM_VERSION,
        showXcodeLog: true,
        device,
      });
      await wda.xcodebuild.start(true);
    });

    after(async function () {
      this.timeout(MOCHA_TIMEOUT_MS);

      await shutdownSimulator(device);

      await simctl.deleteDevice();
    });

    describe('with running sim', function () {
      this.timeout(6 * 60 * 1000);
      beforeEach(async function () {
        await killAllSimulators();
        await device.run({startupTimeout: SIM_STARTUP_TIMEOUT_MS});
      });
      afterEach(async function () {
        try {
          await retryInterval(5, 1000, async function () {
            await shutdownSimulator(device);
          });
        } catch (ign) {}
      });

      it('should launch agent on a sim', async function () {
        const agent = new WebDriverAgent(xcodeVersion, getStartOpts(device));

        await agent.launch('sessionId');
        await axios({url: testUrl}).should.be.eventually.rejected;
        await agent.quit();
      });

      it('should fail if xcodebuild fails', async function () {
        // short timeout
        this.timeout(35 * 1000);

        const agent = new WebDriverAgent(xcodeVersion, getStartOpts(device));

        agent.xcodebuild.createSubProcess = async function () { // eslint-disable-line require-await
          let args = [
            '-workspace',
            `${this.agentPath}dfgs`,
            // '-scheme',
            // 'XCTUITestRunner',
            // '-destination',
            // `id=${this.device.udid}`,
            // 'test'
          ];
          return new SubProcess('xcodebuild', args, {detached: true});
        };

        await agent.launch('sessionId')
          .should.eventually.be.rejectedWith('xcodebuild failed');

        await agent.quit();
      });
    });
  });
});

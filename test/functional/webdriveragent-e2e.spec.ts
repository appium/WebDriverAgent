import {Simctl} from 'node-simctl';
import {getSimulator} from 'appium-ios-simulator';
import {killAllSimulators, shutdownSimulator} from './helpers/simulator.js';
import {SubProcess} from 'teen_process';
import {PLATFORM_VERSION, DEVICE_NAME} from './desired.js';
import {retryInterval} from 'asyncbox';
import {WebDriverAgent} from '../../lib/webdriveragent.js';
import axios from 'axios';
import type {AppleDevice} from '../../lib/types.js';
import {describe, before, after, beforeEach, afterEach, it} from 'node:test';
import assert from 'node:assert/strict';

type SimulatorTestDevice = AppleDevice & {simctl: Simctl};

const SIM_DEVICE_NAME = 'webDriverAgentTest';
const SIM_STARTUP_TIMEOUT_MS = 60 * 1000 * 5;

const testUrl = 'http://localhost:8100/tree';

function getStartOpts(device: AppleDevice) {
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
  describe('with fresh sim', function () {
    let device: SimulatorTestDevice;
    let simctl: Simctl;

    before(async function () {
      simctl = new Simctl();
      simctl.udid = await simctl.createDevice(SIM_DEVICE_NAME, DEVICE_NAME, PLATFORM_VERSION);
      device = (await getSimulator(simctl.udid)) as SimulatorTestDevice;

      // Prebuild WDA
      const wda = new WebDriverAgent({
        iosSdkVersion: PLATFORM_VERSION,
        platformVersion: PLATFORM_VERSION,
        showXcodeLog: true,
        device,
      });
      if (wda.xcodebuild) {
        await wda.xcodebuild.start(true);
      }
    });

    after(async function () {
      await shutdownSimulator(device);

      await simctl.deleteDevice();
    });

    describe('with running sim', function () {
      beforeEach(async function () {
        await killAllSimulators();
        await device.simctl.startBootMonitor({
          shouldPreboot: true,
          timeout: SIM_STARTUP_TIMEOUT_MS,
        });
      });
      afterEach(async function () {
        try {
          await retryInterval(5, 1000, async function () {
            await shutdownSimulator(device);
          });
        } catch {}
      });

      it('should launch agent on a sim', async function () {
        const agent = new WebDriverAgent(getStartOpts(device));

        await agent.launch('sessionId');
        await assert.rejects(() => axios({url: testUrl}), /Request failed with status code 404/);
        await agent.quit();
      });

      it('should fail if xcodebuild fails', async function () {
        const agent = new WebDriverAgent(getStartOpts(device));
        (agent.xcodebuild as any).createSubProcess = async function () {
          const args = [
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

        await assert.rejects(() => agent.launch('sessionId'), /xcodebuild failed/);

        await agent.quit();
      });
    });
  });
});

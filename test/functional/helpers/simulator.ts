import {Simctl} from 'node-simctl';

import type {AppleDevice} from '../../../lib/types.js';
import {DEVICE_NAME} from '../desired.js';

const LOCAL_SIM_BOOT_TIMEOUT_MS = 60 * 1000 * 5;

/**
 * Locates the simulator these tests should run against.
 *
 * In CI, the workflow boots and settles a simulator ahead of time (via
 * `futureware-tech/simulator-action` + `Scripts/ci/wait-for-simulator-idle.mjs`) and passes its
 * UDID through `SIMULATOR_UDID` - these tests must not boot their own there, since CI applies the
 * settle-wait stability fix once per job, not once per test file.
 *
 * Locally (no CI env), that setup isn't guaranteed, so this boots the existing simulator matching
 * DEVICE_NAME if it isn't already running. It never creates a new device - if none matches, it
 * throws and lists what's available.
 */
export async function getTargetDevice(): Promise<AppleDevice> {
  if (process.env.CI) {
    if (!process.env.SIMULATOR_UDID) {
      throw new Error(
        'SIMULATOR_UDID is not set. In CI, these tests expect the workflow to have already booted ' +
          'and settled a simulator (see .github/workflows/functional-test.yml) and passed its UDID through.',
      );
    }
    return {udid: process.env.SIMULATOR_UDID};
  }

  const simctl = new Simctl();
  const allDevices = Object.values(await simctl.getDevices()).flat();
  const device = allDevices.find((d) => d.name === DEVICE_NAME);
  if (!device) {
    const available = [...new Set(allDevices.map((d) => d.name))].sort().join(', ');
    throw new Error(`No simulator named '${DEVICE_NAME}' exists. Available simulators: ${available || '(none)'}`);
  }

  if (device.state !== 'Booted') {
    simctl.udid = device.udid;
    await simctl.startBootMonitor({shouldPreboot: true, timeout: LOCAL_SIM_BOOT_TIMEOUT_MS});
  }

  return {udid: device.udid};
}

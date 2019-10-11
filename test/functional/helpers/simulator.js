import _ from 'lodash';
import { getDevices, shutdown, deleteDevice } from 'node-simctl';
import { retryInterval } from 'asyncbox';
import { killAllSimulators as simKill } from 'appium-ios-simulator';
import { resetTestProcesses } from '../../../lib/utils';


async function killAllSimulators () {
  if (process.env.CLOUD) {
    return;
  }

  const allDevices = _.flatMap(_.values(await getDevices()));
  const bootedDevices = allDevices.filter((device) => device.state === 'Booted');

  for (const {udid} of bootedDevices) {
    // It is necessary to stop the corresponding xcodebuild process before killing
    // the simulator, otherwise it will be automatically restarted
    await resetTestProcesses(udid, true);
    await shutdown(udid);
  }
  await simKill();
}

async function shutdownSimulator (device) {
  // stop XCTest processes if running to avoid unexpected side effects
  await resetTestProcesses(device.udid, true);
  await device.shutdown();
}

async function deleteDeviceWithRetry (udid) {
  try {
    await retryInterval(10, 1000, deleteDevice, udid);
  } catch (ign) {}
}


export { killAllSimulators, shutdownSimulator, deleteDeviceWithRetry };

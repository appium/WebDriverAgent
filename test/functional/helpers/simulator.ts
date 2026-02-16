import _ from 'lodash';
import {Simctl} from 'node-simctl';
import {retryInterval} from 'asyncbox';
import {killAllSimulators as simKill} from 'appium-ios-simulator';
import {resetTestProcesses} from '../../../lib/utils';
import type {AppleDevice} from '../../../lib/types';

export async function killAllSimulators(): Promise<void> {
  const simctl = new Simctl();
  const allDevices = _.flatMap(_.values(await simctl.getDevices()));
  const bootedDevices = allDevices.filter((device) => device.state === 'Booted');

  for (const {udid} of bootedDevices) {
    // It is necessary to stop the corresponding xcodebuild process before killing
    // the simulator, otherwise it will be automatically restarted
    await resetTestProcesses(udid, true);
    simctl.udid = udid;
    await simctl.shutdownDevice();
  }
  await simKill();
}

export async function shutdownSimulator(device: AppleDevice): Promise<void> {
  // stop XCTest processes if running to avoid unexpected side effects
  await resetTestProcesses(device.udid, true);
  await device.shutdown();
}

export async function deleteDeviceWithRetry(udid: string): Promise<void> {
  const simctl = new Simctl({udid});
  try {
    await retryInterval(10, 1000, simctl.deleteDevice.bind(simctl));
  } catch {}
}

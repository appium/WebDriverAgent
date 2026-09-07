import assert from 'node:assert/strict';
import {test} from 'node:test';

import {ensureSimulator} from './ensure-simulator.mjs';

const options = {os: 'tvOS', version: '18.5', model: 'Apple TV 4K (3rd generation)'};
const runtime = {
  identifier: 'com.apple.CoreSimulator.SimRuntime.tvOS-18-5',
  version: '18.5.0',
  isAvailable: true,
};
const deviceType = {name: options.model, identifier: 'com.apple.CoreSimulator.SimDeviceType.Apple-TV'};

function simulatorCommands({runtimes = [runtime], devices = {}, downloadSucceeds = true} = {}) {
  const calls = [];
  const run = async (command, args) => {
    calls.push([command, ...args]);
    if (command === 'xcodebuild') {
      if (downloadSucceeds) {
        runtimes = [runtime];
      }
      return {stdout: ''};
    }
    if (args[1] === 'create') {
      return {stdout: 'created-udid\n'};
    }
    return {stdout: JSON.stringify({runtimes, devices, devicetypes: [deviceType]})};
  };
  return {calls, run};
}

test('reuses a matching available device without downloading or creating anything', async () => {
  const {calls, run} = simulatorCommands({
    devices: {[runtime.identifier]: [{name: options.model, isAvailable: true, udid: 'existing-udid'}]},
  });
  assert.equal(await ensureSimulator(options, run), 'existing-udid');
  assert.ok(calls.every(([command, , action]) => command === 'xcrun' && action === 'list'));
});

test('creates the requested device on an installed runtime, ignoring unavailable devices', async () => {
  const {calls, run} = simulatorCommands({
    devices: {[runtime.identifier]: [{name: options.model, isAvailable: false, udid: 'unavailable'}]},
  });
  assert.equal(await ensureSimulator(options, run), 'created-udid');
  assert.deepEqual(calls.at(-1), [
    'xcrun',
    'simctl',
    'create',
    options.model,
    deviceType.identifier,
    runtime.identifier,
  ]);
  assert.ok(!calls.some(([command]) => command === 'xcodebuild'));
});

test('downloads the exact missing version before creating its simulator', async () => {
  const {calls, run} = simulatorCommands({
    runtimes: [{...runtime, identifier: 'com.apple.CoreSimulator.SimRuntime.tvOS-26-5', version: '26.5'}],
  });
  assert.equal(await ensureSimulator(options, run), 'created-udid');
  assert.deepEqual(
    calls.find(([command]) => command === 'xcodebuild'),
    ['xcodebuild', '-downloadPlatform', 'tvOS', '-buildVersion', '18.5'],
  );
});

test('fails instead of silently selecting another runtime when installation does not help', async () => {
  const {calls, run} = simulatorCommands({runtimes: [], downloadSucceeds: false});
  await assert.rejects(ensureSimulator(options, run), /still unavailable/);
  assert.ok(!calls.some(([, , action]) => action === 'create'));
});

test('rejects an unsupported model before attempting a runtime download', async () => {
  const {calls, run} = simulatorCommands({runtimes: []});
  await assert.rejects(ensureSimulator({...options, model: 'Unknown device'}, run), /does not support/);
  assert.ok(!calls.some(([command]) => command === 'xcodebuild'));
});

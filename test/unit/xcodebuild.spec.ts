import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {describe, it, beforeEach, mock} from 'node:test';

import * as teenProcess from 'teen_process';

import type {XcodeBuildArgs} from '../../lib/types.js';
import * as utilsIndex from '../../lib/utils/index.js';

let currentExec: (...args: any[]) => any = async () => ({stdout: '', stderr: ''});

mock.module('teen_process', {
  namedExports: {
    ...teenProcess,
    exec: (...args: any[]) => currentExec(...args),
  },
});

let currentSetXctestrunFile: (...args: any[]) => any = async () => '/fake/WebDriverAgentRunner.xctestrun';

mock.module('../../lib/utils/index.js', {
  namedExports: {
    ...utilsIndex,
    setXctestrunFile: (...args: any[]) => currentSetXctestrunFile(...args),
  },
});

const {XcodeBuild} = await import('../../lib/xcodebuild.js');

const SHOWDESTINATIONS_OUTPUT = `
\tDestinations compatible with the "WebDriverAgentRunner" scheme:
\t\t{ platform:iOS, id:00008030-000A49391460202E, name:iPad von Galyna }
\t\t{ platform:iOS Simulator, id:BB720847-B182-40BD-BB5A-338951D32ADC, OS:27.0, name:iPad (A16) }
`;

function makeXcodeBuild(udid: string, realDevice: boolean): InstanceType<typeof XcodeBuild> {
  const args: XcodeBuildArgs = {
    realDevice,
    agentPath: '/fake/WebDriverAgent.xcodeproj',
    bootstrapPath: '/fake',
  };
  return new XcodeBuild({udid}, args);
}

describe('XcodeBuild real-device udid case resolution', function () {
  beforeEach(function () {
    currentExec = async () => ({stdout: SHOWDESTINATIONS_OUTPUT, stderr: ''});
  });

  it('resolves to the canonical case xcodebuild reports', async function () {
    const xcodebuild = makeXcodeBuild('00008030-000a49391460202e', true);
    const resolved = await (xcodebuild as any).resolveXcodeDeviceUdid();
    assert.strictEqual(resolved, '00008030-000A49391460202E');
  });

  it('falls back to the given udid when no destination matches', async function () {
    const xcodebuild = makeXcodeBuild('unknown-udid', true);
    const resolved = await (xcodebuild as any).resolveXcodeDeviceUdid();
    assert.strictEqual(resolved, 'unknown-udid');
  });

  it("falls back to the given udid when 'xcodebuild -showdestinations' fails", async function () {
    currentExec = async () => {
      throw new Error('boom');
    };
    const xcodebuild = makeXcodeBuild('some-udid', true);
    const resolved = await (xcodebuild as any).resolveXcodeDeviceUdid();
    assert.strictEqual(resolved, 'some-udid');
  });

  it('is a no-op for simulators, whose udid is already canonical', async function () {
    let execCalled = false;
    currentExec = async () => {
      execCalled = true;
      return {stdout: '', stderr: ''};
    };
    const xcodebuild = makeXcodeBuild('sim-udid', false);
    const resolved = await (xcodebuild as any).resolveXcodeDeviceUdid();
    assert.strictEqual(execCalled, false);
    assert.strictEqual(resolved, 'sim-udid');
  });

  it("only shells out to 'xcodebuild -showdestinations' once even if resolution is triggered multiple times", async function () {
    let execCallCount = 0;
    currentExec = async () => {
      execCallCount++;
      return {stdout: SHOWDESTINATIONS_OUTPUT, stderr: ''};
    };
    const xcodebuild = makeXcodeBuild('00008030-000a49391460202e', true);
    await (xcodebuild as any).resolveXcodeDeviceUdid();
    await (xcodebuild as any).resolveXcodeDeviceUdid();
    assert.strictEqual(execCallCount, 1);
  });

  it('lets truly concurrent callers await the same in-flight resolution instead of racing ahead', async function () {
    let execCallCount = 0;
    let releaseExec: () => void = () => {};
    const execGate = new Promise<void>((resolve) => {
      releaseExec = resolve;
    });
    currentExec = async () => {
      execCallCount++;
      await execGate;
      return {stdout: SHOWDESTINATIONS_OUTPUT, stderr: ''};
    };
    const xcodebuild = makeXcodeBuild('00008030-000a49391460202e', true);

    // Both calls start before the (gated) exec() resolves — a naive "already started" boolean
    // would let the second one return immediately with a value that isn't resolved yet.
    const first = (xcodebuild as any).resolveXcodeDeviceUdid();
    const second = (xcodebuild as any).resolveXcodeDeviceUdid();
    releaseExec();
    const [firstResolved, secondResolved] = await Promise.all([first, second]);

    assert.strictEqual(execCallCount, 1);
    assert.strictEqual(firstResolved, '00008030-000A49391460202E');
    assert.strictEqual(secondResolved, '00008030-000A49391460202E');
  });

  it("builds the '-destination id=' argument from the resolved udid", async function () {
    const xcodebuild = makeXcodeBuild('00008030-000a49391460202e', true);
    const resolved = await (xcodebuild as any).resolveXcodeDeviceUdid();
    const {args} = (xcodebuild as any).getCommand(false, resolved);
    assert.ok(args.includes('id=00008030-000A49391460202E'));
  });

  it("bounds 'xcodebuild -showdestinations' with a timeout", async function () {
    let capturedOpts: any;
    currentExec = async (_cmd: string, _args: string[], opts: any) => {
      capturedOpts = opts;
      return {stdout: SHOWDESTINATIONS_OUTPUT, stderr: ''};
    };
    const xcodebuild = makeXcodeBuild('00008030-000a49391460202e', true);
    await (xcodebuild as any).resolveXcodeDeviceUdid();
    assert.ok(typeof capturedOpts?.timeout === 'number' && capturedOpts.timeout > 0);
  });

  it('falls back to the given udid when resolution times out', async function () {
    currentExec = async () => {
      throw new Error("Command 'xcodebuild ...' timed out after 15000ms");
    };
    const xcodebuild = makeXcodeBuild('some-udid', true);
    const resolved = await (xcodebuild as any).resolveXcodeDeviceUdid();
    assert.strictEqual(resolved, 'some-udid');
  });

  it("keeps the caller's udid casing for the .xctestrun file lookup, unaffected by resolution", async function () {
    let capturedDeviceInfo: any;
    currentSetXctestrunFile = async ({deviceInfo}: any) => {
      capturedDeviceInfo = deviceInfo;
      return '/fake/WebDriverAgentRunner.xctestrun';
    };
    const xcodebuild = new XcodeBuild(
      {udid: '00008030-000a49391460202e'},
      {
        realDevice: true,
        agentPath: '/fake/WebDriverAgent.xcodeproj',
        bootstrapPath: '/fake',
        useXctestrunFile: true,
      },
    );
    await xcodebuild.init({} as any);
    assert.strictEqual(capturedDeviceInfo.udid, '00008030-000a49391460202e');
  });
});

describe('XcodeBuild readiness after a previous process exits', function () {
  function setup() {
    const build = new XcodeBuild(
      {udid: 'sim-udid'},
      {
        realDevice: false,
        agentPath: '/fake',
        bootstrapPath: '/fake',
        prebuildDelay: 0,
      },
    );
    const processes: EventEmitter[] = [];
    let statusCalls = 0;
    const status = {ready: true};
    (build as any).noSessionProxy = {
      timeout: 5000,
      command: async () => {
        statusCalls++;
        return status;
      },
    };
    (build as any).createSubProcess = async (buildOnly: boolean) => {
      const process = new EventEmitter();
      processes.push(process);
      (process as any).start = async () => {
        if (buildOnly) {
          process.emit('exit', 0, null);
        }
      };
      return process;
    };
    return {build, processes, status, statusCalls: () => statusCalls};
  }

  it('checks status after a successful prebuild', async function () {
    const fixture = setup();
    await fixture.build.prebuild();
    assert.deepStrictEqual(await fixture.build.start(), fixture.status);
    assert.strictEqual(fixture.statusCalls(), 1);
  });

  it('checks status again when restarting the same instance', async function () {
    const fixture = setup();
    await fixture.build.start();
    fixture.processes[0].emit('exit', 0, null);
    assert.deepStrictEqual(await fixture.build.start(), fixture.status);
    assert.strictEqual(fixture.statusCalls(), 2);
  });

  it('does not let an old process exit mark the new process as exited', async function () {
    const fixture = setup();
    await fixture.build.start();
    const create = (fixture.build as any).createSubProcess;
    (fixture.build as any).createSubProcess = async (buildOnly: boolean) => {
      const process = await create(buildOnly);
      process.start = async () => {
        fixture.processes[0].emit('exit', 0, null);
      };
      return process;
    };
    assert.deepStrictEqual(await fixture.build.start(), fixture.status);
    assert.strictEqual(fixture.statusCalls(), 2);
  });
});

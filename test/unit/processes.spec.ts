import assert from 'node:assert/strict';
import {describe, beforeEach, it, mock} from 'node:test';

interface ExecCall {
  cmd: string;
  args: string[];
}

let pgrepStdout = '';
let cmdlineByPid: Record<string, string> = {};
let killedPids: string[] = [];
const execCalls: ExecCall[] = [];

async function fakeExec(cmd: string, args: string[] = []): Promise<{stdout: string}> {
  execCalls.push({cmd, args});
  if (cmd === 'pgrep') {
    return {stdout: pgrepStdout};
  }
  if (cmd === 'ps') {
    const pid = args[args.indexOf('-p') + 1];
    return {stdout: cmdlineByPid[pid] ?? ''};
  }
  if (cmd === 'kill') {
    if (args[0] === '-0') {
      // Report the process as already gone, so killAppUsingPattern does not
      // wait out the full polling window on every signal.
      throw Object.assign(new Error('No such process'), {code: 1});
    }
    killedPids.push(...args.filter((a) => !a.startsWith('-')));
    return {stdout: ''};
  }
  throw new Error(`Unexpected exec call: ${cmd} ${args.join(' ')}`);
}

mock.module('teen_process', {
  namedExports: {
    exec: (...args: [string, string[]?]) => fakeExec(...args),
  },
});

const {killAppUsingPattern, resetTestProcesses} = await import('../../lib/utils/processes.js');
const {XCODEBUILD_PROCESS_MARKER} = await import('../../lib/constants.js');

describe('processes', function () {
  beforeEach(function () {
    pgrepStdout = '';
    cmdlineByPid = {};
    killedPids = [];
    execCalls.length = 0;
  });

  describe('#killAppUsingPattern', function () {
    it('kills every matched pid when no cmdline filter is given', async function () {
      pgrepStdout = '111 222';
      await killAppUsingPattern('xcodebuild.*some-udid');
      assert.deepStrictEqual(killedPids.sort(), ['111', '222']);
    });

    it('only kills pids whose full command line contains the given substring', async function () {
      pgrepStdout = '111 222';
      cmdlineByPid = {
        111: `xcodebuild -destination id=some-udid ${XCODEBUILD_PROCESS_MARKER}`,
        222: 'xcodebuild -destination id=some-udid', // unrelated xcodebuild instance, no marker
      };
      await killAppUsingPattern('xcodebuild.*some-udid', XCODEBUILD_PROCESS_MARKER);
      assert.deepStrictEqual(killedPids, ['111']);
    });

    it('kills nothing when no matched pid contains the required substring', async function () {
      pgrepStdout = '222';
      cmdlineByPid = {
        222: 'xcodebuild -destination id=some-udid',
      };
      await killAppUsingPattern('xcodebuild.*some-udid', XCODEBUILD_PROCESS_MARKER);
      assert.deepStrictEqual(killedPids, []);
    });
  });

  describe('#resetTestProcesses', function () {
    it('scopes the xcodebuild pattern to this package own processes on a real device', async function () {
      pgrepStdout = '111 222';
      cmdlineByPid = {
        111: `xcodebuild -destination id=some-udid ${XCODEBUILD_PROCESS_MARKER}`,
        222: 'xcodebuild -destination id=some-udid', // e.g. a separately managed WDA instance
      };
      await resetTestProcesses('some-udid', false);
      assert.deepStrictEqual(killedPids, ['111']);
    });

    it('does not apply the marker filter to the simulator XCTRunner/xctest patterns', async function () {
      pgrepStdout = '333';
      cmdlineByPid = {
        333: 'some-path/XCTRunner some-udid', // no marker present, unlike the xcodebuild process
      };
      await resetTestProcesses('some-udid', true);
      assert.ok(killedPids.includes('333'));
    });
  });
});

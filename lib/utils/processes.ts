import {waitForCondition} from 'asyncbox';
import {exec} from 'teen_process';

import {XCODEBUILD_PROCESS_MARKER} from '../constants.js';
import {log} from '../logger.js';

/**
 * Find and terminate all processes matching the given pgrep pattern.
 *
 * @param pgrepPattern - Pattern used to find candidate processes.
 * @param cmdlineIncludes - If given, a candidate is only killed if its full
 * command line also contains this substring. Used to narrow a broad pgrep
 * match (e.g. by device udid) down to processes this package actually started.
 */
export async function killAppUsingPattern(pgrepPattern: string, cmdlineIncludes?: string): Promise<void> {
  const signals = [2, 15, 9];
  for (const signal of signals) {
    const matchedPids = await getPIDsUsingPattern(pgrepPattern, cmdlineIncludes);
    if (matchedPids.length === 0) {
      return;
    }
    const args = [`-${signal}`, ...matchedPids];
    try {
      await exec('kill', args);
    } catch (err: any) {
      log.debug(`kill ${args.join(' ')} -> ${err.message}`);
    }
    if (signal === signals[signals.length - 1]) {
      // there is no need to wait after SIGKILL
      return;
    }
    try {
      await waitForCondition(
        async () => {
          const pidCheckPromises = matchedPids.map(async (pid) => {
            try {
              await exec('kill', ['-0', pid]);
              // the process is still alive
              return false;
            } catch {
              // the process is dead
              return true;
            }
          });
          return (await Promise.all(pidCheckPromises)).every((x) => x === true);
        },
        {
          waitMs: 1000,
          intervalMs: 100,
        },
      );
      return;
    } catch {
      // try the next signal
    }
  }
}

/**
 * Kills running XCTest processes for the particular device.
 *
 * The `xcodebuild` pattern is additionally scoped to processes this package started
 * (see {@link XCODEBUILD_PROCESS_MARKER}), so other XCTest-based tools targeting the
 * same udid (e.g. a separately managed WebDriverAgent instance) are left alone.
 * The XCTRunner/xctest patterns below cannot be scoped the same way, since those
 * processes do not inherit xcodebuild's command line.
 */
export async function resetTestProcesses(udid: string, isSimulator: boolean): Promise<void> {
  const processPatterns = [`xcodebuild.*${udid}`];
  if (isSimulator) {
    processPatterns.push(`${udid}.*XCTRunner`);
    // Some XCTest launches might not include xcodebuild in their command line
    processPatterns.push(`xctest.*${udid}`);
  }
  log.debug(`Killing running processes '${processPatterns.join(', ')}' for the device ${udid}...`);
  await Promise.all(
    processPatterns.map((pattern) =>
      killAppUsingPattern(pattern, pattern.startsWith('xcodebuild') ? XCODEBUILD_PROCESS_MARKER : undefined),
    ),
  );
}

/**
 * Filters a list of PIDs down to those whose full command line satisfies the
 * given lambda. PIDs that have already exited are silently dropped.
 */
async function filterPIDsByCommandLine(
  pids: string[],
  filteringFunc: (cmdline: string) => boolean | Promise<boolean>,
): Promise<string[]> {
  const filtered = await Promise.all(
    pids.map(async (pid) => {
      let stdout: string;
      try {
        ({stdout} = await exec('ps', ['-p', pid, '-o', 'command']));
      } catch (e: any) {
        if (e.code === 1) {
          // The process does not exist anymore, there's nothing to filter
          return null;
        }
        throw e;
      }
      return (await filteringFunc(stdout)) ? pid : null;
    }),
  );
  return filtered.filter((pid): pid is string => Boolean(pid));
}

/**
 * Get the IDs of processes listening on the particular system port.
 * It is also possible to apply additional filtering based on the
 * process command line.
 *
 * @param port - The port number.
 * @param filteringFunc - Optional lambda function, which
 *                                    receives command line string of the particular process
 *                                    listening on given port, and is expected to return
 *                                    either true or false to include/exclude the corresponding PID
 *                                    from the resulting array.
 * @returns - the list of matched process ids.
 */
export async function getPIDsListeningOnPort(
  port: string | number,
  filteringFunc: ((cmdline: string) => boolean | Promise<boolean>) | null = null,
): Promise<string[]> {
  const result: string[] = [];
  try {
    // This only works since Mac OS X El Capitan
    const {stdout} = await exec('lsof', ['-ti', `tcp:${port}`]);
    result.push(...stdout.trim().split(/\n+/));
  } catch (e: any) {
    if (e.code !== 1) {
      // code 1 means no processes. Other errors need reporting
      log.debug(`Error getting processes listening on port '${port}': ${e.stderr || e.message}`);
    }
    return result;
  }

  if (typeof filteringFunc !== 'function') {
    return result;
  }
  return await filterPIDsByCommandLine(result, filteringFunc);
}

async function getPIDsUsingPattern(pattern: string, cmdlineIncludes?: string): Promise<string[]> {
  const args = [
    '-if', // case insensitive, full cmdline match
    pattern,
  ];
  let pids: string[];
  try {
    const {stdout} = await exec('pgrep', args);
    pids = stdout
      .split(/\s+/)
      .map((x) => parseInt(x, 10))
      .filter(Number.isInteger)
      .map((x) => `${x}`);
  } catch (err: any) {
    log.debug(`'pgrep ${args.join(' ')}' didn't detect any matching processes. Return code: ${err.code}`);
    return [];
  }
  if (!cmdlineIncludes || pids.length === 0) {
    return pids;
  }
  return await filterPIDsByCommandLine(pids, (cmdline) => cmdline.includes(cmdlineIncludes));
}

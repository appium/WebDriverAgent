/* eslint-disable no-console */
import {exec} from 'teen_process';

// `simctl bootstatus` only waits for SpringBoard to become reachable; the simulator's launchd then
// spends tens of seconds to over a minute spawning ~150-250 background daemons, and CPU contention
// from that burst has been observed to turn a single native tap into a 100+ second operation on CI.
// Since `simctl boot`/`bootstatus` give no signal for when the burst ends, this polls the aggregate
// CPU usage of the simulator's process tree (children of its `launchd_sim`) and waits for it to stay
// low for several consecutive samples - a direct measurement of busyness, rather than a guessed sleep.
const CPU_THRESHOLD_PERCENT = Number(process.env.WAIT_SIM_IDLE_CPU_THRESHOLD ?? 20);
const CONSECUTIVE_SAMPLES_NEEDED = Number(process.env.WAIT_SIM_IDLE_CONSECUTIVE ?? 3);
const POLL_INTERVAL_MS = Number(process.env.WAIT_SIM_IDLE_INTERVAL_MS ?? 2000);
const MAX_WAIT_MS = Number(process.env.WAIT_SIM_IDLE_MAX_WAIT_MS ?? 150_000);

const UDID = process.argv[2];
if (!UDID) {
  console.error('Usage: wait-for-simulator-idle.mjs <udid>');
  process.exitCode = 1;
} else {
  await main(UDID);
}

/**
 * @param {string} udid
 */
async function main(udid) {
  console.log(`Waiting for simulator '${udid}' background services to settle...`);

  const start = Date.now();
  let consecutive = 0;
  for (;;) {
    const cpuPercent = await sumChildProcessCpu(udid);
    const elapsedSec = Math.round((Date.now() - start) / 1000);

    if (cpuPercent === null) {
      console.warn(`::warning::Simulator '${udid}' process tree disappeared while waiting; skipping idle check`);
      return;
    }

    if (cpuPercent < CPU_THRESHOLD_PERCENT) {
      consecutive++;
      if (consecutive >= CONSECUTIVE_SAMPLES_NEEDED) {
        console.log(`Simulator settled after ${elapsedSec}s (cpu=${cpuPercent}%)`);
        return;
      }
    } else {
      consecutive = 0;
    }

    if (Date.now() - start >= MAX_WAIT_MS) {
      console.warn(
        `::warning::Simulator '${udid}' did not settle within ${Math.round(MAX_WAIT_MS / 1000)}s (last cpu=${cpuPercent}%); proceeding anyway`,
      );
      return;
    }

    console.log(
      `t+${elapsedSec}s cpu=${cpuPercent}% (need ${CONSECUTIVE_SAMPLES_NEEDED} consecutive samples under ${CPU_THRESHOLD_PERCENT}%, have ${consecutive})`,
    );
    await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
  }
}

/**
 * Sums the %CPU of every direct child of the given simulator's `launchd_sim` - i.e. every process
 * running inside that simulator - or `null` if the simulator's `launchd_sim` can no longer be found.
 * @param {string} udid
 * @returns {Promise<number|null>}
 */
async function sumChildProcessCpu(udid) {
  const {stdout: psOutput} = await exec('ps', ['-Aww', '-o', 'pid=,ppid=,pcpu=,command=']);
  let launchdSimPid = null;
  for (const line of psOutput.split('\n')) {
    if (line.includes('launchd_sim') && line.includes(udid)) {
      launchdSimPid = line.trim().split(/\s+/)[0];
      break;
    }
  }
  if (!launchdSimPid) {
    return null;
  }

  let total = 0;
  for (const line of psOutput.split('\n')) {
    const match = line.trim().match(/^(\d+)\s+(\d+)\s+([\d.]+)\s/);
    if (match && match[2] === launchdSimPid) {
      total += Number(match[3]);
    }
  }
  return Math.round(total);
}

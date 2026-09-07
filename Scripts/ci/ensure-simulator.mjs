/* eslint-disable no-console */
import {execFile} from 'node:child_process';
import {appendFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {promisify} from 'node:util';

const exec = promisify(execFile);

/**
 * Find or create the exact simulator requested by a CI matrix entry.
 * This only provisions the destination; simulator-action handles boot/recovery.
 * @param {{os: string, version: string, model: string}} options
 * @param {typeof exec} run
 * @returns {Promise<string>} Simulator UDID.
 */
export async function ensureSimulator({os, version, model}, run = exec) {
  if (!['iOS', 'tvOS', 'watchOS'].includes(os) || !/^\d+(\.\d+){0,2}$/.test(version) || !model) {
    throw new Error('Usage: ensure-simulator.mjs <iOS|tvOS|watchOS> <version> <model>');
  }
  const options = {maxBuffer: 10 * 1024 * 1024};
  const readList = async (kind) => {
    const {stdout} = await run('xcrun', ['simctl', 'list', kind, '--json'], options);
    return JSON.parse(stdout)[kind];
  };
  const deviceType = (await readList('devicetypes')).find((type) => type.name === model);
  if (!deviceType) {
    throw new Error(`Selected Xcode does not support simulator model '${model}'`);
  }
  const normalizedVersion = version.split('.').map(Number);
  const matchesRuntime = (runtime) =>
    runtime.isAvailable &&
    runtime.identifier.startsWith(`com.apple.CoreSimulator.SimRuntime.${os}-`) &&
    [0, 1, 2].every((index) => Number(runtime.version.split('.')[index] ?? 0) === (normalizedVersion[index] ?? 0));
  let runtime = (await readList('runtimes')).find(matchesRuntime);
  if (!runtime) {
    console.log(`Installing missing ${os} ${version} simulator runtime...`);
    await run('xcodebuild', ['-downloadPlatform', os, '-buildVersion', version], options);
    runtime = (await readList('runtimes')).find(matchesRuntime);
  }
  if (!runtime) {
    throw new Error(`${os} ${version} is still unavailable after downloading the runtime`);
  }
  const devices = (await readList('devices'))[runtime.identifier] ?? [];
  const existing = devices.find((device) => device.name === model && device.isAvailable);
  if (existing) {
    return existing.udid;
  }
  const {stdout} = await run('xcrun', ['simctl', 'create', model, deviceType.identifier, runtime.identifier], options);
  const udid = stdout.trim();
  if (!udid) {
    throw new Error(`simctl did not return a UDID for '${model}'`);
  }
  return udid;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [os, version, model] = process.argv.slice(2);
  const udid = await ensureSimulator({os, version, model});
  console.log(`Simulator destination: ${model} (${os} ${version}), ${udid}`);
  if (process.env.GITHUB_OUTPUT) {
    await appendFile(process.env.GITHUB_OUTPUT, `udid=${udid}\n`);
  }
}

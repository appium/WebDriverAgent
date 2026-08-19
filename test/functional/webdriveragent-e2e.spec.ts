import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {describe, before, afterEach, it} from 'node:test';

import type {AppleDevice} from '../../lib/types.js';
import {WebDriverAgent} from '../../lib/webdriveragent.js';
import {PLATFORM_NAME, PLATFORM_VERSION} from './desired.js';
import {getTargetDevice} from './helpers/simulator.js';

const WDA_BASE_URL = 'http://localhost:8100';

function getStartOpts(device: AppleDevice) {
  return {
    device,
    platformName: PLATFORM_NAME,
    platformVersion: PLATFORM_VERSION,
    host: 'localhost',
    port: 8100,
    realDevice: false,
    showXcodeLog: true,
    wdaLaunchTimeout: 60 * 3 * 1000,
  };
}

// /status and /source are both routed `.withoutSession` in WebDriverAgentLib, so they can be hit
// directly after `launch()` without this package having to create a real WDA session first.
async function assertWdaIsResponding(): Promise<void> {
  const statusResponse = await fetch(`${WDA_BASE_URL}/status`);
  assert.equal(statusResponse.status, 200);
  const status = (await statusResponse.json()) as {value: {state: string; build: {productBundleIdentifier: string}}};
  assert.equal(status.value.state, 'success');
  assert.equal(typeof status.value.build.productBundleIdentifier, 'string');

  const sourceResponse = await fetch(`${WDA_BASE_URL}/source`);
  assert.equal(sourceResponse.status, 200);
  const source = (await sourceResponse.json()) as {value: string};
  assert.equal(typeof source.value, 'string');
  assert.ok(source.value.length > 0, 'expected /source to return non-empty page source');

  await assertSessionScopedSourceWorks();
}

// The sessionId passed to `agent.launch()` is only used for Appium-side proxy bookkeeping - it
// never reaches WDA. Fetching source through `/session/:sessionId/source` (the form Appium
// actually uses) needs a real WDA-issued session, created here via `POST /session`.
async function assertSessionScopedSourceWorks(): Promise<void> {
  const createSessionResponse = await fetch(`${WDA_BASE_URL}/session`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({capabilities: {alwaysMatch: {}, firstMatch: [{}]}}),
  });
  assert.equal(createSessionResponse.status, 200);
  const session = (await createSessionResponse.json()) as {value: {sessionId: string}};
  const wdaSessionId = session.value.sessionId;
  assert.equal(typeof wdaSessionId, 'string');

  try {
    const sessionSourceResponse = await fetch(`${WDA_BASE_URL}/session/${wdaSessionId}/source`);
    assert.equal(sessionSourceResponse.status, 200);
    const sessionSource = (await sessionSourceResponse.json()) as {value: string};
    assert.ok(sessionSource.value.length > 0, 'expected session-scoped /source to return non-empty page source');
  } finally {
    await fetch(`${WDA_BASE_URL}/session/${wdaSessionId}`, {method: 'DELETE'});
  }
}

// Assumes a simulator is already booted and settled (the CI workflow, or the developer locally,
// is responsible for that - see helpers/simulator.ts#getTargetDevice). These tests only cover
// WDA build+startup, so they don't manage the simulator's lifecycle themselves.
describe('WebDriverAgent', function () {
  let device: AppleDevice;
  let agent: WebDriverAgent | undefined;

  before(async function () {
    device = await getTargetDevice();
  });

  // Guarantees WDA gets shut down even if the test itself throws (e.g. a failed assertion),
  // so a leftover process/port doesn't take down the next test too.
  afterEach(async function () {
    await agent?.quit();
    agent = undefined;
  });

  it('should build and start WDA from sources', async function () {
    agent = new WebDriverAgent(getStartOpts(device));

    await agent.launch(randomUUID());
    await assertWdaIsResponding();
  });

  it('should start WDA from a prebuilt binary', async function () {
    // Relies on the build products the previous test already produced, exercising the
    // `usePrebuiltWDA` (test-without-building) xcodebuild code path instead of a full rebuild.
    agent = new WebDriverAgent({...getStartOpts(device), usePrebuiltWDA: true});

    await agent.launch(randomUUID());
    await assertWdaIsResponding();
  });
});

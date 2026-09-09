import assert from 'node:assert/strict';
import {mkdtemp, readFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {afterEach, beforeEach, describe, it, mock} from 'node:test';

import {strongbox} from '@appium/strongbox';
import {fs} from '@appium/support';
import sinon from 'sinon';

import {BOOTSTRAP_PATH} from '../../lib/utils/index.js';

let container: string;
function isolatedStrongbox(name: string) {
  const box = strongbox(name);
  // Preserve the temporary path verbatim instead of Strongbox's container slugification.
  Object.defineProperty(box, 'container', {value: container});
  return box;
}
mock.module('@appium/strongbox', {
  namedExports: {
    strongbox: isolatedStrongbox,
  },
});
const {WebDriverAgent} = await import('../../lib/webdriveragent.js');
const packageInfo = JSON.parse(await readFile(path.join(BOOTSTRAP_PATH, 'package.json'), 'utf8'));
const itemName = 'recentWdaModuleVersion';

describe('WDA project cleanup persistence', function () {
  let sandbox: sinon.SinonSandbox;
  let legacyMarker: sinon.SinonStub;

  beforeEach(async function () {
    container = await mkdtemp(path.join(tmpdir(), 'wda-cleanup-'));
    sandbox = sinon.createSandbox();
    legacyMarker = sandbox
      .stub(fs, 'exists')
      .withArgs(path.resolve(process.env.HOME ?? '', '.appium', 'webdriveragent', 'upgrade.time'))
      .resolves(false);
  });

  afterEach(async function () {
    sandbox.restore();
    await rm(container, {recursive: true, force: true});
  });

  function newAgent() {
    const agent = new WebDriverAgent({device: {udid: 'test-udid'}, platformVersion: '17.2'});
    const clean = sandbox.stub(agent.xcodebuild, 'cleanProject').resolves();
    return {clean, run: async () => await (agent as any)._cleanupProjectIfFresh()};
  }

  async function persist(version: string) {
    await isolatedStrongbox(packageInfo.name).createItemWithValue(itemName, version);
  }

  async function persistedVersion() {
    return (await isolatedStrongbox(packageInfo.name).createItem<string>(itemName)).value;
  }

  it('reuses the persisted version despite a legacy marker across new agents', async function () {
    legacyMarker.resolves(true);
    await persist(packageInfo.version);
    for (let i = 0; i < 2; i++) {
      const agent = newAgent();
      await agent.run();
      sandbox.assert.notCalled(agent.clean);
    }
    sandbox.assert.notCalled(legacyMarker);
    assert.equal(await persistedVersion(), packageInfo.version);
  });

  it('cleans an older persisted version once without a legacy marker', async function () {
    await persist('5.0.0');
    const first = newAgent();
    await first.run();
    sandbox.assert.calledOnce(first.clean);
    assert.equal(await persistedVersion(), packageInfo.version);
    const second = newAgent();
    await second.run();
    sandbox.assert.notCalled(second.clean);
    sandbox.assert.notCalled(legacyMarker);
  });

  it('initializes missing version state without consulting a legacy marker', async function () {
    legacyMarker.resolves(true);
    const first = newAgent();
    await first.run();
    sandbox.assert.notCalled(first.clean);
    assert.equal(await persistedVersion(), packageInfo.version);
    const second = newAgent();
    await second.run();
    sandbox.assert.notCalled(second.clean);
    sandbox.assert.notCalled(legacyMarker);
  });

  it('initializes a fresh installation without cleaning', async function () {
    for (let i = 0; i < 2; i++) {
      const agent = newAgent();
      await agent.run();
      sandbox.assert.notCalled(agent.clean);
    }
    sandbox.assert.notCalled(legacyMarker);
    assert.equal(await persistedVersion(), packageInfo.version);
  });

  it('preserves a newer persisted version', async function () {
    await persist('999.0.0');
    const agent = newAgent();
    await agent.run();
    sandbox.assert.notCalled(agent.clean);
    assert.equal(await persistedVersion(), '999.0.0');
  });

  it('repairs a damaged persisted version without treating it as legacy state', async function () {
    legacyMarker.resolves(true);
    await persist('not-a-version');
    const agent = newAgent();
    await agent.run();
    sandbox.assert.notCalled(agent.clean);
    sandbox.assert.notCalled(legacyMarker);
    assert.equal(await persistedVersion(), packageInfo.version);
  });

  it('retries cleanup after a failure without recording a successful upgrade', async function () {
    await persist('5.0.0');
    const first = newAgent();
    first.clean.rejects(new Error('cleanup failed'));
    await first.run();
    assert.equal(await persistedVersion(), '5.0.0');
    const second = newAgent();
    await second.run();
    sandbox.assert.calledOnce(second.clean);
    assert.equal(await persistedVersion(), packageInfo.version);
  });
});

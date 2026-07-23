import {BOOTSTRAP_PATH} from '../../lib/utils/index.js';
import {selectWdaStartupStrategyName} from '../../lib/wda-strategies.js';
import * as utils from '../../lib/utils/index.js';
import path from 'node:path';
import sinon from 'sinon';
import esmock from 'esmock';
import type {WebDriverAgentArgs} from '../../lib/types.js';
import type * as WebDriverAgentModule from '../../lib/webdriveragent.js';
import {describe, beforeEach, afterEach, it} from 'node:test';
import assert from 'node:assert/strict';

let currentGetWDAUpgradeTimestamp: (...args: any[]) => any = utils.getWDAUpgradeTimestamp;

const {WebDriverAgent} = await esmock<typeof WebDriverAgentModule>(
  '../../lib/webdriveragent.js',
  import.meta.url,
  {},
  {
    '../../lib/utils/index.js': {
      getWDAUpgradeTimestamp: (...args: any[]) => currentGetWDAUpgradeTimestamp(...args),
    },
  },
);

const fakeConstructorArgs: WebDriverAgentArgs = {
  device: {
    udid: 'some-sim-udid',
  },
  platformVersion: '9',
  host: 'me',
  realDevice: false,
};

const defaultAgentPath = path.resolve(BOOTSTRAP_PATH, 'WebDriverAgent.xcodeproj');
const customBootstrapPath = '/path/to/wda';
const customAgentPath = '/path/to/some/agent/WebDriverAgent.xcodeproj';
const customDerivedDataPath = '/path/to/some/agent/DerivedData/';

describe('WebDriverAgent', function () {
  describe('startup strategy selection', function () {
    it('should select an existing-url strategy for external WDA URLs', function () {
      assert.strictEqual(
        selectWdaStartupStrategyName({webDriverAgentUrl: 'http://127.0.0.1:8100'}),
        'existing-url',
      );
    });

    it('should select a simulator strategy for simulator sessions', function () {
      assert.strictEqual(selectWdaStartupStrategyName({realDevice: false}), 'simulator');
    });

    it('should select a real-device preinstalled strategy for no-xcode real-device sessions', function () {
      assert.strictEqual(
        selectWdaStartupStrategyName({realDevice: true, usePreinstalledWDA: true}),
        'real-device-preinstalled',
      );
    });

    it('should select a real-device xcodebuild strategy for default real-device sessions', function () {
      assert.strictEqual(
        selectWdaStartupStrategyName({realDevice: true}),
        'real-device-xcodebuild',
      );
    });
  });

  describe('Constructor', function () {
    it('should have a default wda agent if not specified', function () {
      const agent = new WebDriverAgent(fakeConstructorArgs);
      assert.strictEqual(agent.bootstrapPath, BOOTSTRAP_PATH);
      assert.strictEqual(agent.agentPath, defaultAgentPath);
    });
    it('should have custom wda bootstrap and default agent if only bootstrap specified', function () {
      const agent = new WebDriverAgent({
        ...fakeConstructorArgs,
        bootstrapPath: customBootstrapPath,
      });
      assert.strictEqual(agent.bootstrapPath, customBootstrapPath);
      assert.strictEqual(
        agent.agentPath,
        path.resolve(customBootstrapPath, 'WebDriverAgent.xcodeproj'),
      );
    });
    it('should have custom wda bootstrap and agent if both specified', function () {
      const agent = new WebDriverAgent({
        ...fakeConstructorArgs,
        bootstrapPath: customBootstrapPath,
        agentPath: customAgentPath,
      });
      assert.strictEqual(agent.bootstrapPath, customBootstrapPath);
      assert.strictEqual(agent.agentPath, customAgentPath);
    });
    it('should have custom derivedDataPath if specified', async function () {
      const agent = new WebDriverAgent({
        ...fakeConstructorArgs,
        derivedDataPath: customDerivedDataPath,
      });
      if (agent.xcodebuild) {
        assert.strictEqual(await agent.xcodebuild.retrieveDerivedDataPath(), customDerivedDataPath);
      }
    });

    it('should not create xcodebuild for real-device preinstalled sessions', function () {
      const agent = new WebDriverAgent({
        ...fakeConstructorArgs,
        realDevice: true,
        usePreinstalledWDA: true,
      });
      assert.throws(() => agent.xcodebuild, /xcodebuild is not available/);
    });
  });

  describe('launch', function () {
    it('should use webDriverAgentUrl override and return current status', async function () {
      const override = 'http://mockurl:8100/';
      const args = Object.assign({}, fakeConstructorArgs);
      args.webDriverAgentUrl = override;
      const agent = new WebDriverAgent(args);
      const wdaStub = sinon.stub(agent as any, 'getStatus');
      wdaStub.callsFake(function () {
        return {build: 'data'};
      });

      assert.deepStrictEqual(await agent.launch('sessionId'), {build: 'data'});
      assert.strictEqual(agent.url.href, override);
      if (agent.jwproxy) {
        assert.strictEqual(agent.jwproxy.server, 'mockurl');
        assert.strictEqual(agent.jwproxy.port, 8100);
        assert.strictEqual(agent.jwproxy.base, '');
        assert.strictEqual(agent.jwproxy.scheme, 'http');
      }
      if (agent.noSessionProxy) {
        assert.strictEqual(agent.noSessionProxy.server, 'mockurl');
        assert.strictEqual(agent.noSessionProxy.port, 8100);
        assert.strictEqual(agent.noSessionProxy.base, '');
        assert.strictEqual(agent.noSessionProxy.scheme, 'http');
      }
      wdaStub.reset();
    });
  });

  describe('use wda proxy url', function () {
    it('should use webDriverAgentUrl wda proxy url', async function () {
      const override = 'http://127.0.0.1:8100/aabbccdd';
      const args = Object.assign({}, fakeConstructorArgs);
      args.webDriverAgentUrl = override;
      const agent = new WebDriverAgent(args);
      const wdaStub = sinon.stub(agent as any, 'getStatus');
      wdaStub.callsFake(function () {
        return {build: 'data'};
      });

      assert.deepStrictEqual(await agent.launch('sessionId'), {build: 'data'});

      assert.strictEqual(agent.url.port, '8100');
      assert.strictEqual(agent.url.hostname, '127.0.0.1');
      assert.strictEqual(agent.url.pathname, '/aabbccdd');
      if (agent.jwproxy) {
        assert.strictEqual(agent.jwproxy.server, '127.0.0.1');
        assert.strictEqual(agent.jwproxy.port, 8100);
        assert.strictEqual(agent.jwproxy.base, '/aabbccdd');
        assert.strictEqual(agent.jwproxy.scheme, 'http');
      }
      if (agent.noSessionProxy) {
        assert.strictEqual(agent.noSessionProxy.server, '127.0.0.1');
        assert.strictEqual(agent.noSessionProxy.port, 8100);
        assert.strictEqual(agent.noSessionProxy.base, '/aabbccdd');
        assert.strictEqual(agent.noSessionProxy.scheme, 'http');
      }
    });
  });

  describe('get url', function () {
    it('should use default WDA listening url', function () {
      const args = Object.assign({}, fakeConstructorArgs);
      const agent = new WebDriverAgent(args);
      assert.strictEqual(agent.url.href, 'http://127.0.0.1:8100/');
      (agent as any).setupProxies('mysession');
      if (agent.jwproxy) {
        assert.strictEqual(agent.jwproxy.scheme, 'http');
      }
      if (agent.noSessionProxy) {
        assert.strictEqual(agent.noSessionProxy.scheme, 'http');
      }
    });
    it('should use default WDA listening url with emply base url', function () {
      const wdaLocalPort = '9100';
      const wdaBaseUrl = '';

      const args = Object.assign({}, fakeConstructorArgs);
      args.wdaBaseUrl = wdaBaseUrl;
      args.wdaLocalPort = parseInt(wdaLocalPort, 10);

      const agent = new WebDriverAgent(args);
      assert.strictEqual(agent.url.href, 'http://127.0.0.1:9100/');
      (agent as any).setupProxies('mysession');
      if (agent.jwproxy) {
        assert.strictEqual(agent.jwproxy.scheme, 'http');
      }
      if (agent.noSessionProxy) {
        assert.strictEqual(agent.noSessionProxy.scheme, 'http');
      }
    });
    it('should use customised WDA listening url', function () {
      const wdaLocalPort = '9100';
      const wdaBaseUrl = 'http://mockurl';

      const args = Object.assign({}, fakeConstructorArgs);
      args.wdaBaseUrl = wdaBaseUrl;
      args.wdaLocalPort = parseInt(wdaLocalPort, 10);

      const agent = new WebDriverAgent(args);
      assert.strictEqual(agent.url.href, 'http://mockurl:9100/');
      (agent as any).setupProxies('mysession');
      if (agent.jwproxy) {
        assert.strictEqual(agent.jwproxy.scheme, 'http');
      }
      if (agent.noSessionProxy) {
        assert.strictEqual(agent.noSessionProxy.scheme, 'http');
      }
    });
    it('should use customised WDA listening url with slash', function () {
      const wdaLocalPort = '9100';
      const wdaBaseUrl = 'http://mockurl/';

      const args = Object.assign({}, fakeConstructorArgs);
      args.wdaBaseUrl = wdaBaseUrl;
      args.wdaLocalPort = parseInt(wdaLocalPort, 10);

      const agent = new WebDriverAgent(args);
      assert.strictEqual(agent.url.href, 'http://mockurl:9100/');
      (agent as any).setupProxies('mysession');
      if (agent.jwproxy) {
        assert.strictEqual(agent.jwproxy.scheme, 'http');
      }
      if (agent.noSessionProxy) {
        assert.strictEqual(agent.noSessionProxy.scheme, 'http');
      }
    });
    it('should use the given webDriverAgentUrl and ignore other params', function () {
      const args = Object.assign({}, fakeConstructorArgs);
      args.wdaBaseUrl = 'http://mockurl/';
      args.wdaLocalPort = 9100;
      args.webDriverAgentUrl = 'https://127.0.0.1:8100/';

      const agent = new WebDriverAgent(args);
      assert.strictEqual(agent.url.href, 'https://127.0.0.1:8100/');
    });
    it('should set scheme to https for https webDriverAgentUrl', function () {
      const args = Object.assign({}, fakeConstructorArgs);
      args.webDriverAgentUrl = 'https://127.0.0.1:8100/';
      const agent = new WebDriverAgent(args);
      (agent as any).setupProxies('mysession');
      if (agent.jwproxy) {
        assert.strictEqual(agent.jwproxy.scheme, 'https');
      }
      if (agent.noSessionProxy) {
        assert.strictEqual(agent.noSessionProxy.scheme, 'https');
      }
    });

    it('should accept scheme-less webDriverAgentUrl values', function () {
      const args = Object.assign({}, fakeConstructorArgs);
      args.webDriverAgentUrl = 'localhost:8100/aabbccdd';
      const agent = new WebDriverAgent(args);
      assert.strictEqual(agent.url.href, 'http://localhost:8100/aabbccdd');
      (agent as any).setupProxies('mysession');
      if (agent.jwproxy) {
        assert.strictEqual(agent.jwproxy.scheme, 'http');
      }
    });

    it('should throw for invalid webDriverAgentUrl with explicit scheme', function () {
      const args = Object.assign({}, fakeConstructorArgs);
      args.webDriverAgentUrl = 'http://';
      const agent = new WebDriverAgent(args);
      assert.throws(() => agent.url);
    });
  });

  describe('setupCaching()', function () {
    let wda: InstanceType<typeof WebDriverAgent>;
    let wdaStub: sinon.SinonStub;
    const getTimestampStub = sinon.stub();
    currentGetWDAUpgradeTimestamp = getTimestampStub;

    beforeEach(function () {
      wda = new WebDriverAgent(fakeConstructorArgs);
      wdaStub = sinon.stub(wda as any, 'getStatus');
    });

    afterEach(function () {
      for (const stub of [wdaStub, getTimestampStub]) {
        if (stub) {
          stub.reset();
        }
      }
    });

    it('should not cache when no WDA is running', async function () {
      wdaStub.callsFake(function () {
        return null;
      });

      assert.strictEqual(await wda.setupCaching(), undefined);
      assert.strictEqual(wdaStub.calledOnce, true);
      assert.strictEqual(wda.webDriverAgentUrl, undefined);
    });

    it('should cache when running WDA has only time', async function () {
      wdaStub.callsFake(function () {
        return {build: {time: 'Jun 24 2018 17:08:21'}};
      });

      assert.strictEqual(await wda.setupCaching(), 'http://127.0.0.1:8100/');
      assert.strictEqual(wdaStub.calledOnce, true);
      assert.strictEqual(wda.webDriverAgentUrl, 'http://127.0.0.1:8100/');
    });

    it('should not cache when bundle id is not default without updatedWDABundleId capability', async function () {
      wdaStub.callsFake(function () {
        return {
          build: {
            time: 'Jun 24 2018 17:08:21',
            productBundleIdentifier: 'com.example.WebDriverAgent',
          },
        };
      });

      assert.strictEqual(await wda.setupCaching(), undefined);
      assert.strictEqual(wdaStub.calledOnce, true);
      assert.strictEqual(wda.webDriverAgentUrl, undefined);
    });

    it('should not cache when bundle id is different with updatedWDABundleId capability', async function () {
      wdaStub.callsFake(function () {
        return {
          build: {
            time: 'Jun 24 2018 17:08:21',
            productBundleIdentifier: 'com.example.different.WebDriverAgent',
          },
        };
      });

      assert.strictEqual(await wda.setupCaching(), undefined);
      assert.strictEqual(wdaStub.calledOnce, true);
      assert.strictEqual(wda.webDriverAgentUrl, undefined);
    });

    it('should cache when bundle id is equal to updatedWDABundleId capability', async function () {
      wda = new WebDriverAgent({
        ...fakeConstructorArgs,
        updatedWDABundleId: 'com.example.WebDriverAgent',
      });
      wdaStub = sinon.stub(wda as any, 'getStatus');

      wdaStub.callsFake(function () {
        return {
          build: {
            time: 'Jun 24 2018 17:08:21',
            productBundleIdentifier: 'com.example.WebDriverAgent',
          },
        };
      });

      assert.strictEqual(await wda.setupCaching(), 'http://127.0.0.1:8100/');
      assert.strictEqual(wdaStub.calledOnce, true);
      assert.strictEqual(wda.webDriverAgentUrl, 'http://127.0.0.1:8100/');
    });

    it('should not cache if current revision differs from the bundled one', async function () {
      wdaStub.callsFake(function () {
        return {build: {upgradedAt: '1'}};
      });
      getTimestampStub.callsFake(async () => 2);

      assert.strictEqual(await wda.setupCaching(), undefined);
      assert.strictEqual(wdaStub.calledOnce, true);
      assert.strictEqual(wda.webDriverAgentUrl, undefined);
    });

    it('should cache if current revision is the same as the bundled one', async function () {
      wdaStub.callsFake(function () {
        return {build: {upgradedAt: '1'}};
      });
      getTimestampStub.callsFake(async () => 1);

      assert.strictEqual(await wda.setupCaching(), 'http://127.0.0.1:8100/');
      assert.strictEqual(wdaStub.calledOnce, true);
      assert.strictEqual(wda.webDriverAgentUrl, 'http://127.0.0.1:8100/');
    });

    it('should cache if current revision cannot be retrieved from WDA status', async function () {
      wdaStub.callsFake(function () {
        return {build: {}};
      });
      getTimestampStub.callsFake(async () => 1);

      assert.strictEqual(await wda.setupCaching(), 'http://127.0.0.1:8100/');
      assert.strictEqual(wdaStub.calledOnce, true);
      assert.strictEqual(wda.webDriverAgentUrl, 'http://127.0.0.1:8100/');
    });

    it('should cache if current revision cannot be retrieved from the file system', async function () {
      wdaStub.callsFake(function () {
        return {build: {upgradedAt: '1'}};
      });
      getTimestampStub.callsFake(async () => null);

      assert.strictEqual(await wda.setupCaching(), 'http://127.0.0.1:8100/');
      assert.strictEqual(wdaStub.calledOnce, true);
      assert.strictEqual(wda.webDriverAgentUrl, 'http://127.0.0.1:8100/');
    });
  });

  describe('usePreinstalledWDA related functions', function () {
    describe('bundleIdForXctest', function () {
      it('should have xctrunner automatically', function () {
        const args = Object.assign({}, fakeConstructorArgs);
        args.updatedWDABundleId = 'io.appium.wda';
        const agent = new WebDriverAgent(args);
        assert.strictEqual(agent.bundleIdForXctest, 'io.appium.wda.xctrunner');
      });

      it('should have xctrunner automatically with default bundle id', function () {
        const args = Object.assign({}, fakeConstructorArgs);
        const agent = new WebDriverAgent(args);
        assert.strictEqual(agent.bundleIdForXctest, 'com.facebook.WebDriverAgentRunner.xctrunner');
      });

      it('should allow an empty string as xctrunner suffix', function () {
        const args = Object.assign({}, fakeConstructorArgs);
        args.updatedWDABundleId = 'io.appium.wda';
        args.updatedWDABundleIdSuffix = '';
        const agent = new WebDriverAgent(args);
        assert.strictEqual(agent.bundleIdForXctest, 'io.appium.wda');
      });

      it('should allow an empty string as xctrunner suffix with default bundle id', function () {
        const args = Object.assign({}, fakeConstructorArgs);
        args.updatedWDABundleIdSuffix = '';
        const agent = new WebDriverAgent(args);
        assert.strictEqual(agent.bundleIdForXctest, 'com.facebook.WebDriverAgentRunner');
      });

      it('should have an arbitrary xctrunner suffix', function () {
        const args = Object.assign({}, fakeConstructorArgs);
        args.updatedWDABundleId = 'io.appium.wda';
        args.updatedWDABundleIdSuffix = '.customsuffix';
        const agent = new WebDriverAgent(args);
        assert.strictEqual(agent.bundleIdForXctest, 'io.appium.wda.customsuffix');
      });
    });

    describe('host operations', function () {
      let sandbox: sinon.SinonSandbox;

      beforeEach(function () {
        sandbox = sinon.createSandbox();
      });

      afterEach(function () {
        sandbox.restore();
      });

      it('should delegate real-device preinstalled launch and terminate to injected host ops', async function () {
        const launchPreinstalled = sandbox.stub().resolves();
        const terminate = sandbox.stub().resolves();
        const agent = new WebDriverAgent({
          ...fakeConstructorArgs,
          device: {udid: 'real-device-udid'},
          realDevice: true,
          usePreinstalledWDA: true,
          wdaLocalPort: 9100,
          updatedWDABundleId: 'io.appium.wda',
          mjpegServerPort: 9200,
          wdaBindingIP: '127.0.0.1',
          maxHttpRequestBodySize: 1024,
          hostOps: {
            realDevicePreinstalled: {
              launchPreinstalled,
              terminate,
            },
          },
        });
        sandbox.stub(agent as any, 'getStatus').resolves({build: 'data'});

        assert.deepStrictEqual(await agent.launch('sessionId'), {build: 'data'});
        sinon.assert.calledOnce(launchPreinstalled);
        assert.partialDeepStrictEqual(launchPreinstalled.firstCall.args[0], {
          udid: 'real-device-udid',
          bundleId: 'io.appium.wda.xctrunner',
          wdaLocalPort: 9100,
        });
        assert.deepStrictEqual(launchPreinstalled.firstCall.args[0].env, {
          USE_PORT: 9100,
          WDA_PRODUCT_BUNDLE_IDENTIFIER: 'io.appium.wda.xctrunner',
          MJPEG_SERVER_PORT: 9200,
          USE_IP: '127.0.0.1',
          MAX_HTTP_REQUEST_BODY_SIZE: 1024,
        });

        await agent.quit();
        sinon.assert.calledOnceWithExactly(terminate, {
          udid: 'real-device-udid',
          bundleId: 'io.appium.wda.xctrunner',
        });
      });

      it('should require injected host ops for real-device preinstalled launch', async function () {
        const agent = new WebDriverAgent({
          ...fakeConstructorArgs,
          device: {udid: 'real-device-udid'},
          realDevice: true,
          usePreinstalledWDA: true,
        });

        await assert.rejects(agent.launch('sessionId'), 'Host operations must be provided');
      });
    });
  });
});

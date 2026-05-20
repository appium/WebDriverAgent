import chai, {expect} from 'chai';
import chaiAsPromised from 'chai-as-promised';
import {BOOTSTRAP_PATH} from '../../lib/utils';
import {WebDriverAgent} from '../../lib/webdriveragent';
import * as utils from '../../lib/utils';
import path from 'node:path';
import sinon from 'sinon';
import type {WebDriverAgentArgs} from '../../lib/types';
import type {Simctl} from 'node-simctl';
import type {Devicectl} from 'node-devicectl';

chai.use(chaiAsPromised);

const fakeConstructorArgs: WebDriverAgentArgs = {
  device: {
    udid: 'some-sim-udid',
    simctl: {} as Simctl,
    devicectl: {} as Devicectl,
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
  describe('Constructor', function () {
    it('should have a default wda agent if not specified', function () {
      const agent = new WebDriverAgent(fakeConstructorArgs);
      expect(agent.bootstrapPath).to.eql(BOOTSTRAP_PATH);
      expect(agent.agentPath).to.eql(defaultAgentPath);
    });
    it('should have custom wda bootstrap and default agent if only bootstrap specified', function () {
      const agent = new WebDriverAgent({
        ...fakeConstructorArgs,
        bootstrapPath: customBootstrapPath,
      });
      expect(agent.bootstrapPath).to.eql(customBootstrapPath);
      expect(agent.agentPath).to.eql(path.resolve(customBootstrapPath, 'WebDriverAgent.xcodeproj'));
    });
    it('should have custom wda bootstrap and agent if both specified', function () {
      const agent = new WebDriverAgent({
        ...fakeConstructorArgs,
        bootstrapPath: customBootstrapPath,
        agentPath: customAgentPath,
      });
      expect(agent.bootstrapPath).to.eql(customBootstrapPath);
      expect(agent.agentPath).to.eql(customAgentPath);
    });
    it('should have custom derivedDataPath if specified', async function () {
      const agent = new WebDriverAgent({
        ...fakeConstructorArgs,
        derivedDataPath: customDerivedDataPath,
      });
      if (agent.xcodebuild) {
        expect(await agent.retrieveDerivedDataPath()).to.eql(customDerivedDataPath);
      }
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

      await expect(agent.launch('sessionId')).to.eventually.eql({build: 'data'});
      expect(agent.url.href).to.eql(override);
      if (agent.jwproxy) {
        expect(agent.jwproxy.server).to.eql('mockurl');
        expect(agent.jwproxy.port).to.eql(8100);
        expect(agent.jwproxy.base).to.eql('');
        expect(agent.jwproxy.scheme).to.eql('http');
      }
      if (agent.noSessionProxy) {
        expect(agent.noSessionProxy.server).to.eql('mockurl');
        expect(agent.noSessionProxy.port).to.eql(8100);
        expect(agent.noSessionProxy.base).to.eql('');
        expect(agent.noSessionProxy.scheme).to.eql('http');
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

      await expect(agent.launch('sessionId')).to.eventually.eql({build: 'data'});

      expect(agent.url.port).to.eql('8100');
      expect(agent.url.hostname).to.eql('127.0.0.1');
      expect(agent.url.pathname).to.eql('/aabbccdd');
      if (agent.jwproxy) {
        expect(agent.jwproxy.server).to.eql('127.0.0.1');
        expect(agent.jwproxy.port).to.eql(8100);
        expect(agent.jwproxy.base).to.eql('/aabbccdd');
        expect(agent.jwproxy.scheme).to.eql('http');
      }
      if (agent.noSessionProxy) {
        expect(agent.noSessionProxy.server).to.eql('127.0.0.1');
        expect(agent.noSessionProxy.port).to.eql(8100);
        expect(agent.noSessionProxy.base).to.eql('/aabbccdd');
        expect(agent.noSessionProxy.scheme).to.eql('http');
      }
    });
  });

  describe('get url', function () {
    it('should use default WDA listening url', function () {
      const args = Object.assign({}, fakeConstructorArgs);
      const agent = new WebDriverAgent(args);
      expect(agent.url.href).to.eql('http://127.0.0.1:8100/');
      (agent as any).setupProxies('mysession');
      if (agent.jwproxy) {
        expect(agent.jwproxy.scheme).to.eql('http');
      }
      if (agent.noSessionProxy) {
        expect(agent.noSessionProxy.scheme).to.eql('http');
      }
    });
    it('should use default WDA listening url with emply base url', function () {
      const wdaLocalPort = '9100';
      const wdaBaseUrl = '';

      const args = Object.assign({}, fakeConstructorArgs);
      args.wdaBaseUrl = wdaBaseUrl;
      args.wdaLocalPort = parseInt(wdaLocalPort, 10);

      const agent = new WebDriverAgent(args);
      expect(agent.url.href).to.eql('http://127.0.0.1:9100/');
      (agent as any).setupProxies('mysession');
      if (agent.jwproxy) {
        expect(agent.jwproxy.scheme).to.eql('http');
      }
      if (agent.noSessionProxy) {
        expect(agent.noSessionProxy.scheme).to.eql('http');
      }
    });
    it('should use customised WDA listening url', function () {
      const wdaLocalPort = '9100';
      const wdaBaseUrl = 'http://mockurl';

      const args = Object.assign({}, fakeConstructorArgs);
      args.wdaBaseUrl = wdaBaseUrl;
      args.wdaLocalPort = parseInt(wdaLocalPort, 10);

      const agent = new WebDriverAgent(args);
      expect(agent.url.href).to.eql('http://mockurl:9100/');
      (agent as any).setupProxies('mysession');
      if (agent.jwproxy) {
        expect(agent.jwproxy.scheme).to.eql('http');
      }
      if (agent.noSessionProxy) {
        expect(agent.noSessionProxy.scheme).to.eql('http');
      }
    });
    it('should use customised WDA listening url with slash', function () {
      const wdaLocalPort = '9100';
      const wdaBaseUrl = 'http://mockurl/';

      const args = Object.assign({}, fakeConstructorArgs);
      args.wdaBaseUrl = wdaBaseUrl;
      args.wdaLocalPort = parseInt(wdaLocalPort, 10);

      const agent = new WebDriverAgent(args);
      expect(agent.url.href).to.eql('http://mockurl:9100/');
      (agent as any).setupProxies('mysession');
      if (agent.jwproxy) {
        expect(agent.jwproxy.scheme).to.eql('http');
      }
      if (agent.noSessionProxy) {
        expect(agent.noSessionProxy.scheme).to.eql('http');
      }
    });
    it('should use the given webDriverAgentUrl and ignore other params', function () {
      const args = Object.assign({}, fakeConstructorArgs);
      args.wdaBaseUrl = 'http://mockurl/';
      args.wdaLocalPort = 9100;
      args.webDriverAgentUrl = 'https://127.0.0.1:8100/';

      const agent = new WebDriverAgent(args);
      expect(agent.url.href).to.eql('https://127.0.0.1:8100/');
    });
    it('should set scheme to https for https webDriverAgentUrl', function () {
      const args = Object.assign({}, fakeConstructorArgs);
      args.webDriverAgentUrl = 'https://127.0.0.1:8100/';
      const agent = new WebDriverAgent(args);
      (agent as any).setupProxies('mysession');
      if (agent.jwproxy) {
        expect(agent.jwproxy.scheme).to.eql('https');
      }
      if (agent.noSessionProxy) {
        expect(agent.noSessionProxy.scheme).to.eql('https');
      }
    });

    it('should accept scheme-less webDriverAgentUrl values', function () {
      const args = Object.assign({}, fakeConstructorArgs);
      args.webDriverAgentUrl = 'localhost:8100/aabbccdd';
      const agent = new WebDriverAgent(args);
      expect(agent.url.href).to.eql('http://localhost:8100/aabbccdd');
      (agent as any).setupProxies('mysession');
      if (agent.jwproxy) {
        expect(agent.jwproxy.scheme).to.eql('http');
      }
    });

    it('should throw for invalid webDriverAgentUrl with explicit scheme', function () {
      const args = Object.assign({}, fakeConstructorArgs);
      args.webDriverAgentUrl = 'http://';
      const agent = new WebDriverAgent(args);
      expect(() => agent.url).to.throw();
    });
  });

  describe('setupCaching()', function () {
    let wda: WebDriverAgent;
    let wdaStub: sinon.SinonStub;
    const getTimestampStub = sinon.stub(utils, 'getWDAUpgradeTimestamp');

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

      expect(await wda.setupCaching()).to.be.undefined;
      expect(wdaStub.calledOnce).to.be.true;
      expect(wda.webDriverAgentUrl === undefined).to.be.true;
    });

    it('should cache when running WDA has only time', async function () {
      wdaStub.callsFake(function () {
        return {build: {time: 'Jun 24 2018 17:08:21'}};
      });

      expect(await wda.setupCaching()).to.equal('http://127.0.0.1:8100/');
      expect(wdaStub.calledOnce).to.be.true;
      expect(wda.webDriverAgentUrl).to.equal('http://127.0.0.1:8100/');
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

      expect(await wda.setupCaching()).to.be.undefined;
      expect(wdaStub.calledOnce).to.be.true;
      expect(wda.webDriverAgentUrl === undefined).to.be.true;
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

      expect(await wda.setupCaching()).to.be.undefined;
      expect(wdaStub.calledOnce).to.be.true;
      expect(wda.webDriverAgentUrl === undefined).to.be.true;
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

      expect(await wda.setupCaching()).to.equal('http://127.0.0.1:8100/');
      expect(wdaStub.calledOnce).to.be.true;
      expect(wda.webDriverAgentUrl).to.equal('http://127.0.0.1:8100/');
    });

    it('should not cache if current revision differs from the bundled one', async function () {
      wdaStub.callsFake(function () {
        return {build: {upgradedAt: '1'}};
      });
      getTimestampStub.callsFake(async () => 2);

      expect(await wda.setupCaching()).to.be.undefined;
      expect(wdaStub.calledOnce).to.be.true;
      expect(wda.webDriverAgentUrl === undefined).to.be.true;
    });

    it('should cache if current revision is the same as the bundled one', async function () {
      wdaStub.callsFake(function () {
        return {build: {upgradedAt: '1'}};
      });
      getTimestampStub.callsFake(async () => 1);

      expect(await wda.setupCaching()).to.equal('http://127.0.0.1:8100/');
      expect(wdaStub.calledOnce).to.be.true;
      expect(wda.webDriverAgentUrl).to.equal('http://127.0.0.1:8100/');
    });

    it('should cache if current revision cannot be retrieved from WDA status', async function () {
      wdaStub.callsFake(function () {
        return {build: {}};
      });
      getTimestampStub.callsFake(async () => 1);

      expect(await wda.setupCaching()).to.equal('http://127.0.0.1:8100/');
      expect(wdaStub.calledOnce).to.be.true;
      expect(wda.webDriverAgentUrl).to.equal('http://127.0.0.1:8100/');
    });

    it('should cache if current revision cannot be retrieved from the file system', async function () {
      wdaStub.callsFake(function () {
        return {build: {upgradedAt: '1'}};
      });
      getTimestampStub.callsFake(async () => null);

      expect(await wda.setupCaching()).to.equal('http://127.0.0.1:8100/');
      expect(wdaStub.calledOnce).to.be.true;
      expect(wda.webDriverAgentUrl).to.equal('http://127.0.0.1:8100/');
    });
  });

  describe('usePreinstalledWDA related functions', function () {
    describe('bundleIdForXctest', function () {
      it('should have xctrunner automatically', function () {
        const args = Object.assign({}, fakeConstructorArgs);
        args.updatedWDABundleId = 'io.appium.wda';
        const agent = new WebDriverAgent(args);
        expect(agent.bundleIdForXctest).to.equal('io.appium.wda.xctrunner');
      });

      it('should have xctrunner automatically with default bundle id', function () {
        const args = Object.assign({}, fakeConstructorArgs);
        const agent = new WebDriverAgent(args);
        expect(agent.bundleIdForXctest).to.equal('com.facebook.WebDriverAgentRunner.xctrunner');
      });

      it('should allow an empty string as xctrunner suffix', function () {
        const args = Object.assign({}, fakeConstructorArgs);
        args.updatedWDABundleId = 'io.appium.wda';
        args.updatedWDABundleIdSuffix = '';
        const agent = new WebDriverAgent(args);
        expect(agent.bundleIdForXctest).to.equal('io.appium.wda');
      });

      it('should allow an empty string as xctrunner suffix with default bundle id', function () {
        const args = Object.assign({}, fakeConstructorArgs);
        args.updatedWDABundleIdSuffix = '';
        const agent = new WebDriverAgent(args);
        expect(agent.bundleIdForXctest).to.equal('com.facebook.WebDriverAgentRunner');
      });

      it('should have an arbitrary xctrunner suffix', function () {
        const args = Object.assign({}, fakeConstructorArgs);
        args.updatedWDABundleId = 'io.appium.wda';
        args.updatedWDABundleIdSuffix = '.customsuffix';
        const agent = new WebDriverAgent(args);
        expect(agent.bundleIdForXctest).to.equal('io.appium.wda.customsuffix');
      });
    });
  });
});

import chai, { expect } from 'chai';
import chaiAsPromised from 'chai-as-promised';
import { BOOTSTRAP_PATH } from '../../lib/utils';
import { WebDriverAgent } from '../../lib/webdriveragent';
import * as utils from '../../lib/utils';
import path from 'node:path';
import _ from 'lodash';
import sinon from 'sinon';
import type { WebDriverAgentArgs, AppleDevice } from '../../lib/types';

chai.use(chaiAsPromised);

const fakeConstructorArgs: WebDriverAgentArgs = {
  device: {
    udid: 'some-sim-udid',
    simctl: {},
    devicectl: {},
    idb: null
  },
  platformVersion: '9',
  host: 'me',
  realDevice: false
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
    const agent = new WebDriverAgent(_.defaults({
      bootstrapPath: customBootstrapPath,
    }, fakeConstructorArgs));
    expect(agent.bootstrapPath).to.eql(customBootstrapPath);
    expect(agent.agentPath).to.eql(path.resolve(customBootstrapPath, 'WebDriverAgent.xcodeproj'));
  });
  it('should have custom wda bootstrap and agent if both specified', function () {
    const agent = new WebDriverAgent(_.defaults({
      bootstrapPath: customBootstrapPath,
      agentPath: customAgentPath,
    }, fakeConstructorArgs));
    expect(agent.bootstrapPath).to.eql(customBootstrapPath);
    expect(agent.agentPath).to.eql(customAgentPath);
  });
  it('should have custom derivedDataPath if specified', function () {
    const agent = new WebDriverAgent(_.defaults({
      derivedDataPath: customDerivedDataPath
    }, fakeConstructorArgs));
    if (agent.xcodebuild) {
      expect(agent.xcodebuild.derivedDataPath).to.eql(customDerivedDataPath);
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
    expect(agent.url.path).to.eql('/aabbccdd');
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
});

describe('setupCaching()', function () {
  let wda: WebDriverAgent;
  let wdaStub: sinon.SinonStub;
  let wdaStubUninstall: sinon.SinonStub;
  const getTimestampStub = sinon.stub(utils, 'getWDAUpgradeTimestamp');

  beforeEach(function () {
    wda = new WebDriverAgent(fakeConstructorArgs);
    wdaStub = sinon.stub(wda, 'getStatus');
    wdaStubUninstall = sinon.stub(wda as any, 'uninstall');
  });

  afterEach(function () {
    for (const stub of [wdaStub, wdaStubUninstall, getTimestampStub]) {
      if (stub) {
        stub.reset();
      }
    }
  });

  it('should not call uninstall since no Running WDA', async function () {
    wdaStub.callsFake(function () {
      return null;
    });
    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    expect(wdaStub.calledOnce).to.be.true;
    expect(wdaStubUninstall.notCalled).to.be.true;
    expect(_.isUndefined(wda.webDriverAgentUrl)).to.be.true;
  });

  it('should not call uninstall since running WDA has only time', async function () {
    wdaStub.callsFake(function () {
      return {build: { time: 'Jun 24 2018 17:08:21' }};
    });
    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    expect(wdaStub.calledOnce).to.be.true;
    expect(wdaStubUninstall.notCalled).to.be.true;
    expect(wda.webDriverAgentUrl).to.equal('http://127.0.0.1:8100/');
  });

  it('should call uninstall once since bundle id is not default without updatedWDABundleId capability', async function () {
    wdaStub.callsFake(function () {
      return {build: { time: 'Jun 24 2018 17:08:21', productBundleIdentifier: 'com.example.WebDriverAgent' }};
    });
    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    expect(wdaStub.calledOnce).to.be.true;
    expect(wdaStubUninstall.calledOnce).to.be.true;
    expect(_.isUndefined(wda.webDriverAgentUrl)).to.be.true;
  });

  it('should call uninstall once since bundle id is different with updatedWDABundleId capability', async function () {
    wdaStub.callsFake(function () {
      return {build: { time: 'Jun 24 2018 17:08:21', productBundleIdentifier: 'com.example.different.WebDriverAgent' }};
    });

    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    expect(wdaStub.calledOnce).to.be.true;
    expect(wdaStubUninstall.calledOnce).to.be.true;
    expect(_.isUndefined(wda.webDriverAgentUrl)).to.be.true;
  });

  it('should not call uninstall since bundle id is equal to updatedWDABundleId capability', async function () {
    wda = new WebDriverAgent({ ...fakeConstructorArgs, updatedWDABundleId: 'com.example.WebDriverAgent' });
    wdaStub = sinon.stub(wda, 'getStatus');
    wdaStubUninstall = sinon.stub(wda as any, 'uninstall');

    wdaStub.callsFake(function () {
      return {build: { time: 'Jun 24 2018 17:08:21', productBundleIdentifier: 'com.example.WebDriverAgent' }};
    });

    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    expect(wdaStub.calledOnce).to.be.true;
    expect(wdaStubUninstall.notCalled).to.be.true;
    expect(wda.webDriverAgentUrl).to.equal('http://127.0.0.1:8100/');
  });

  it('should call uninstall if current revision differs from the bundled one', async function () {
    wdaStub.callsFake(function () {
      return {build: { upgradedAt: '1' }};
    });
    getTimestampStub.callsFake(() => '2');
    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    expect(wdaStub.calledOnce).to.be.true;
    expect(wdaStubUninstall.calledOnce).to.be.true;
  });

  it('should not call uninstall if current revision is the same as the bundled one', async function () {
    wdaStub.callsFake(function () {
      return {build: { upgradedAt: '1' }};
    });
    getTimestampStub.callsFake(() => '1');
    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    expect(wdaStub.calledOnce).to.be.true;
    expect(wdaStubUninstall.notCalled).to.be.true;
  });

  it('should not call uninstall if current revision cannot be retrieved from WDA status', async function () {
    wdaStub.callsFake(function () {
      return {build: {}};
    });
    getTimestampStub.callsFake(() => '1');
    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    expect(wdaStub.calledOnce).to.be.true;
    expect(wdaStubUninstall.notCalled).to.be.true;
  });

  it('should not call uninstall if current revision cannot be retrieved from the file system', async function () {
    wdaStub.callsFake(function () {
      return {build: { upgradedAt: '1' }};
    });
    getTimestampStub.callsFake(() => null);
    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    expect(wdaStub.calledOnce).to.be.true;
    expect(wdaStubUninstall.notCalled).to.be.true;
  });

  describe('uninstall', function () {
    let device: AppleDevice;
    let wda: WebDriverAgent;
    let deviceGetBundleIdsStub: sinon.SinonStub;
    let deviceRemoveAppStub: sinon.SinonStub;

    beforeEach(function () {
      device = {
        getUserInstalledBundleIdsByBundleName: () => {},
        removeApp: () => {}
      } as any;
      wda = new WebDriverAgent({device} as WebDriverAgentArgs);
      deviceGetBundleIdsStub = sinon.stub(device, 'getUserInstalledBundleIdsByBundleName');
      deviceRemoveAppStub = sinon.stub(device, 'removeApp');
    });

    afterEach(function () {
      for (const stub of [deviceGetBundleIdsStub, deviceRemoveAppStub]) {
        if (stub) {
          stub.reset();
        }
      }
    });

    it('should not call uninstall', async function () {
      deviceGetBundleIdsStub.callsFake(() => []);

      await (wda as any).uninstall();
      expect(deviceGetBundleIdsStub.calledOnce).to.be.true;
      expect(deviceRemoveAppStub.notCalled).to.be.true;
    });

    it('should call uninstall once', async function () {
      const uninstalledBundIds: string[] = [];
      deviceGetBundleIdsStub.callsFake(() => ['com.appium.WDA1']);
      deviceRemoveAppStub.callsFake((id: string) => uninstalledBundIds.push(id));

      await (wda as any).uninstall();
      expect(deviceGetBundleIdsStub.calledOnce).to.be.true;
      expect(deviceRemoveAppStub.calledOnce).to.be.true;
      expect(uninstalledBundIds).to.eql(['com.appium.WDA1']);
    });

    it('should call uninstall twice', async function () {
      const uninstalledBundIds: string[] = [];
      deviceGetBundleIdsStub.callsFake(() => ['com.appium.WDA1', 'com.appium.WDA2']);
      deviceRemoveAppStub.callsFake((id: string) => uninstalledBundIds.push(id));

      await (wda as any).uninstall();
      expect(deviceGetBundleIdsStub.calledOnce).to.be.true;
      expect(deviceRemoveAppStub.calledTwice).to.be.true;
      expect(uninstalledBundIds).to.eql(['com.appium.WDA1', 'com.appium.WDA2']);
    });
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

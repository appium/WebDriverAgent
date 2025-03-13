import { BOOTSTRAP_PATH } from '../../lib/utils';
import { WebDriverAgent } from '../../lib/webdriveragent';
import * as utils from '../../lib/utils';
import path from 'path';
import _ from 'lodash';
import sinon from 'sinon';

const fakeConstructorArgs = {
  device: 'some sim',
  platformVersion: '9',
  host: 'me',
  port: '5000',
  realDevice: false
};

const defaultAgentPath = path.resolve(BOOTSTRAP_PATH, 'WebDriverAgent.xcodeproj');
const customBootstrapPath = '/path/to/wda';
const customAgentPath = '/path/to/some/agent/WebDriverAgent.xcodeproj';
const customDerivedDataPath = '/path/to/some/agent/DerivedData/';

describe('Constructor', function () {
  let chai;

  before(async function() {
    chai = await import('chai');
    const chaiAsPromised = await import('chai-as-promised');

    chai.should();
    chai.use(chaiAsPromised.default);
  });

  it('should have a default wda agent if not specified', function () {
    let agent = new WebDriverAgent({}, fakeConstructorArgs);
    agent.bootstrapPath.should.eql(BOOTSTRAP_PATH);
    agent.agentPath.should.eql(defaultAgentPath);
  });
  it('should have custom wda bootstrap and default agent if only bootstrap specified', function () {
    let agent = new WebDriverAgent({}, _.defaults({
      bootstrapPath: customBootstrapPath,
    }, fakeConstructorArgs));
    agent.bootstrapPath.should.eql(customBootstrapPath);
    agent.agentPath.should.eql(path.resolve(customBootstrapPath, 'WebDriverAgent.xcodeproj'));
  });
  it('should have custom wda bootstrap and agent if both specified', function () {
    let agent = new WebDriverAgent({}, _.defaults({
      bootstrapPath: customBootstrapPath,
      agentPath: customAgentPath,
    }, fakeConstructorArgs));
    agent.bootstrapPath.should.eql(customBootstrapPath);
    agent.agentPath.should.eql(customAgentPath);
  });
  it('should have custom derivedDataPath if specified', function () {
    let agent = new WebDriverAgent({}, _.defaults({
      derivedDataPath: customDerivedDataPath
    }, fakeConstructorArgs));
    agent.xcodebuild.derivedDataPath.should.eql(customDerivedDataPath);
  });
});

describe('launch', function () {
  it('should use webDriverAgentUrl override and return current status', async function () {
    const override = 'http://mockurl:8100/';
    const args = Object.assign({}, fakeConstructorArgs);
    args.webDriverAgentUrl = override;
    const agent = new WebDriverAgent({}, args);
    const wdaStub = sinon.stub(agent, 'getStatus');
    wdaStub.callsFake(function () {
      return {build: 'data'};
    });

    await agent.launch('sessionId').should.eventually.eql({build: 'data'});
    agent.url.href.should.eql(override);
    agent.jwproxy.server.should.eql('mockurl');
    agent.jwproxy.port.should.eql(8100);
    agent.jwproxy.base.should.eql('');
    agent.noSessionProxy.server.should.eql('mockurl');
    agent.noSessionProxy.port.should.eql(8100);
    agent.noSessionProxy.base.should.eql('');
    wdaStub.reset();
  });
});

describe('use wda proxy url', function () {
  it('should use webDriverAgentUrl wda proxy url', async function () {
    const override = 'http://127.0.0.1:8100/aabbccdd';
    const args = Object.assign({}, fakeConstructorArgs);
    args.webDriverAgentUrl = override;
    const agent = new WebDriverAgent({}, args);
    const wdaStub = sinon.stub(agent, 'getStatus');
    wdaStub.callsFake(function () {
      return {build: 'data'};
    });

    await agent.launch('sessionId').should.eventually.eql({build: 'data'});

    agent.url.port.should.eql('8100');
    agent.url.hostname.should.eql('127.0.0.1');
    agent.url.path.should.eql('/aabbccdd');
    agent.jwproxy.server.should.eql('127.0.0.1');
    agent.jwproxy.port.should.eql(8100);
    agent.jwproxy.base.should.eql('/aabbccdd');
    agent.noSessionProxy.server.should.eql('127.0.0.1');
    agent.noSessionProxy.port.should.eql(8100);
    agent.noSessionProxy.base.should.eql('/aabbccdd');
  });
});

describe('get url', function () {
  it('should use default WDA listening url', function () {
    const args = Object.assign({}, fakeConstructorArgs);
    const agent = new WebDriverAgent({}, args);
    agent.url.href.should.eql('http://127.0.0.1:8100/');
  });
  it('should use default WDA listening url with emply base url', function () {
    const wdaLocalPort = '9100';
    const wdaBaseUrl = '';

    const args = Object.assign({}, fakeConstructorArgs);
    args.wdaBaseUrl = wdaBaseUrl;
    args.wdaLocalPort = wdaLocalPort;

    const agent = new WebDriverAgent({}, args);
    agent.url.href.should.eql('http://127.0.0.1:9100/');
  });
  it('should use customised WDA listening url', function () {
    const wdaLocalPort = '9100';
    const wdaBaseUrl = 'http://mockurl';

    const args = Object.assign({}, fakeConstructorArgs);
    args.wdaBaseUrl = wdaBaseUrl;
    args.wdaLocalPort = wdaLocalPort;

    const agent = new WebDriverAgent({}, args);
    agent.url.href.should.eql('http://mockurl:9100/');
  });
  it('should use customised WDA listening url with slash', function () {
    const wdaLocalPort = '9100';
    const wdaBaseUrl = 'http://mockurl/';

    const args = Object.assign({}, fakeConstructorArgs);
    args.wdaBaseUrl = wdaBaseUrl;
    args.wdaLocalPort = wdaLocalPort;

    const agent = new WebDriverAgent({}, args);
    agent.url.href.should.eql('http://mockurl:9100/');
  });
  it('should use the given webDriverAgentUrl and ignore other params', function () {
    const args = Object.assign({}, fakeConstructorArgs);
    args.wdaBaseUrl = 'http://mockurl/';
    args.wdaLocalPort = '9100';
    args.webDriverAgentUrl = 'https://127.0.0.1:8100/';

    const agent = new WebDriverAgent({}, args);
    agent.url.href.should.eql('https://127.0.0.1:8100/');
  });
});

describe('setupCaching()', function () {
  let wda;
  let wdaStub;
  let wdaStubUninstall;
  const getTimestampStub = sinon.stub(utils, 'getWDAUpgradeTimestamp');

  beforeEach(function () {
    wda = new WebDriverAgent('1');
    wdaStub = sinon.stub(wda, 'getStatus');
    wdaStubUninstall = sinon.stub(wda, 'uninstall');
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
    wdaStub.calledOnce.should.be.true;
    wdaStubUninstall.notCalled.should.be.true;
    _.isUndefined(wda.webDriverAgentUrl).should.be.true;
  });

  it('should not call uninstall since running WDA has only time', async function () {
    wdaStub.callsFake(function () {
      return {build: { time: 'Jun 24 2018 17:08:21' }};
    });
    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    wdaStub.calledOnce.should.be.true;
    wdaStubUninstall.notCalled.should.be.true;
    wda.webDriverAgentUrl.should.equal('http://127.0.0.1:8100/');
  });

  it('should call uninstall once since bundle id is not default without updatedWDABundleId capability', async function () {
    wdaStub.callsFake(function () {
      return {build: { time: 'Jun 24 2018 17:08:21', productBundleIdentifier: 'com.example.WebDriverAgent' }};
    });
    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    wdaStub.calledOnce.should.be.true;
    wdaStubUninstall.calledOnce.should.be.true;
    _.isUndefined(wda.webDriverAgentUrl).should.be.true;
  });

  it('should call uninstall once since bundle id is different with updatedWDABundleId capability', async function () {
    wdaStub.callsFake(function () {
      return {build: { time: 'Jun 24 2018 17:08:21', productBundleIdentifier: 'com.example.different.WebDriverAgent' }};
    });

    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    wdaStub.calledOnce.should.be.true;
    wdaStubUninstall.calledOnce.should.be.true;
    _.isUndefined(wda.webDriverAgentUrl).should.be.true;
  });

  it('should not call uninstall since bundle id is equal to updatedWDABundleId capability', async function () {
    wda = new WebDriverAgent('1', { updatedWDABundleId: 'com.example.WebDriverAgent' });
    wdaStub = sinon.stub(wda, 'getStatus');
    wdaStubUninstall = sinon.stub(wda, 'uninstall');

    wdaStub.callsFake(function () {
      return {build: { time: 'Jun 24 2018 17:08:21', productBundleIdentifier: 'com.example.WebDriverAgent' }};
    });

    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    wdaStub.calledOnce.should.be.true;
    wdaStubUninstall.notCalled.should.be.true;
    wda.webDriverAgentUrl.should.equal('http://127.0.0.1:8100/');
  });

  it('should call uninstall if current revision differs from the bundled one', async function () {
    wdaStub.callsFake(function () {
      return {build: { upgradedAt: '1' }};
    });
    getTimestampStub.callsFake(() => '2');
    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    wdaStub.calledOnce.should.be.true;
    wdaStubUninstall.calledOnce.should.be.true;
  });

  it('should not call uninstall if current revision is the same as the bundled one', async function () {
    wdaStub.callsFake(function () {
      return {build: { upgradedAt: '1' }};
    });
    getTimestampStub.callsFake(() => '1');
    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    wdaStub.calledOnce.should.be.true;
    wdaStubUninstall.notCalled.should.be.true;
  });

  it('should not call uninstall if current revision cannot be retrieved from WDA status', async function () {
    wdaStub.callsFake(function () {
      return {build: {}};
    });
    getTimestampStub.callsFake(() => '1');
    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    wdaStub.calledOnce.should.be.true;
    wdaStubUninstall.notCalled.should.be.true;
  });

  it('should not call uninstall if current revision cannot be retrieved from the file system', async function () {
    wdaStub.callsFake(function () {
      return {build: { upgradedAt: '1' }};
    });
    getTimestampStub.callsFake(() => null);
    wdaStubUninstall.callsFake(_.noop);

    await wda.setupCaching();
    wdaStub.calledOnce.should.be.true;
    wdaStubUninstall.notCalled.should.be.true;
  });

  describe('uninstall', function () {
    let device;
    let wda;
    let deviceGetBundleIdsStub;
    let deviceRemoveAppStub;

    beforeEach(function () {
      device = {
        getUserInstalledBundleIdsByBundleName: () => {},
        removeApp: () => {}
      };
      wda = new WebDriverAgent('1', {device});
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

      await wda.uninstall();
      deviceGetBundleIdsStub.calledOnce.should.be.true;
      deviceRemoveAppStub.notCalled.should.be.true;
    });

    it('should call uninstall once', async function () {
      const uninstalledBundIds = [];
      deviceGetBundleIdsStub.callsFake(() => ['com.appium.WDA1']);
      deviceRemoveAppStub.callsFake((id) => uninstalledBundIds.push(id));

      await wda.uninstall();
      deviceGetBundleIdsStub.calledOnce.should.be.true;
      deviceRemoveAppStub.calledOnce.should.be.true;
      uninstalledBundIds.should.eql(['com.appium.WDA1']);
    });

    it('should call uninstall twice', async function () {
      const uninstalledBundIds = [];
      deviceGetBundleIdsStub.callsFake(() => ['com.appium.WDA1', 'com.appium.WDA2']);
      deviceRemoveAppStub.callsFake((id) => uninstalledBundIds.push(id));

      await wda.uninstall();
      deviceGetBundleIdsStub.calledOnce.should.be.true;
      deviceRemoveAppStub.calledTwice.should.be.true;
      uninstalledBundIds.should.eql(['com.appium.WDA1', 'com.appium.WDA2']);
    });
  });
});


describe('usePreinstalledWDA related functions', function () {
  describe('bundleIdForXctest', function () {
    it('should have xctrunner automatically', function () {
      const args = Object.assign({}, fakeConstructorArgs);
      args.updatedWDABundleId = 'io.appium.wda';
      const agent = new WebDriverAgent({}, args);
      agent.bundleIdForXctest.should.equal('io.appium.wda.xctrunner');
    });

    it('should have xctrunner automatically with default bundle id', function () {
      const args = Object.assign({}, fakeConstructorArgs);
      const agent = new WebDriverAgent({}, args);
      agent.bundleIdForXctest.should.equal('com.facebook.WebDriverAgentRunner.xctrunner');
    });

    it('should allow an empty string as xctrunner suffix', function () {
      const args = Object.assign({}, fakeConstructorArgs);
      args.updatedWDABundleId = 'io.appium.wda';
      args.updatedWDABundleIdSuffix = '';
      const agent = new WebDriverAgent({}, args);
      agent.bundleIdForXctest.should.equal('io.appium.wda');
    });

    it('should allow an empty string as xctrunner suffix with default bundle id', function () {
      const args = Object.assign({}, fakeConstructorArgs);
      args.updatedWDABundleIdSuffix = '';
      const agent = new WebDriverAgent({}, args);
      agent.bundleIdForXctest.should.equal('com.facebook.WebDriverAgentRunner');
    });

    it('should have an arbitrary xctrunner suffix', function () {
      const args = Object.assign({}, fakeConstructorArgs);
      args.updatedWDABundleId = 'io.appium.wda';
      args.updatedWDABundleIdSuffix = '.customsuffix';
      const agent = new WebDriverAgent({}, args);
      agent.bundleIdForXctest.should.equal('io.appium.wda.customsuffix');
    });

  });
});

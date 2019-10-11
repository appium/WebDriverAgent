import { WebDriverAgent, BOOTSTRAP_PATH } from '../..';
import * as dependencies from '../../lib/check-dependencies';
import * as utils from '../../lib/utils';
import chai from 'chai';
import chaiAsPromised from 'chai-as-promised';
import path from 'path';
import _ from 'lodash';
import sinon from 'sinon';
import { withMocks } from 'appium-test-support';
import { fs } from 'appium-support';


chai.should();
chai.use(chaiAsPromised);

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

describe('checking for dependencies', function () {
  const wda = new WebDriverAgent('12.1');
  const xcodebuild = wda.xcodebuild;
  describe('#launch', withMocks({wda, fs, dependencies, xcodebuild}, function (mocks) {

    afterEach(function () {
      mocks.verify();
    });

    it('should call checkForDependencies', async function () {
      wda.useXctestrunFile = false;
      wda.usePrebuiltWDA = false;
      wda.derivedDataPath = undefined;
      wda.device = {};
      wda.device.udid = 'udid';

      mocks.wda.expects('setupProxies').once().returns();
      mocks.fs.expects('exists').returns(true);
      mocks.dependencies.expects('checkForDependencies').once().returns(false);
      mocks.xcodebuild.expects('init').once().returns();
      mocks.xcodebuild.expects('start').once().returns();

      await wda.launch();
    });

    it('should call checkForDependencies since only usePrebuiltWDA', async function () {
      wda.useXctestrunFile = false;
      wda.usePrebuiltWDA = true;
      wda.derivedDataPath = undefined;
      wda.device = {};
      wda.device.udid = 'udid';

      mocks.wda.expects('setupProxies').once().returns();
      mocks.fs.expects('exists').returns(true);
      mocks.dependencies.expects('checkForDependencies').once().returns(false);
      mocks.xcodebuild.expects('init').once().returns();
      mocks.xcodebuild.expects('start').once().returns();

      await wda.launch();
    });

    it('should not call checkForDependencies with usePrebuiltWDA and derivedDataPath', async function () {
      wda.useXctestrunFile = false;
      wda.usePrebuiltWDA = true;
      wda.derivedDataPath = 'path/to/data';
      wda.device = {};
      wda.device.udid = 'udid';

      mocks.wda.expects('setupProxies').once().returns();
      mocks.fs.expects('exists').returns(true);
      mocks.dependencies.expects('checkForDependencies').never();
      mocks.xcodebuild.expects('init').once().returns();
      mocks.xcodebuild.expects('start').once().returns();

      await wda.launch();
    });

    it('should not call checkForDependencies with useXctestrunFile', async function () {
      wda.useXctestrunFile = true;
      wda.usePrebuiltWDA = false;
      wda.derivedDataPath = undefined;
      wda.device = {};
      wda.device.udid = 'udid';

      mocks.wda.expects('setupProxies').once().returns();
      mocks.fs.expects('exists').returns(true);
      mocks.dependencies.expects('checkForDependencies').never();
      mocks.xcodebuild.expects('init').once().returns();
      mocks.xcodebuild.expects('start').once().returns();

      await wda.launch();
    });
  }));
});


describe('launch', function () {
  it('should use webDriverAgentUrl override and return current status', async function () {
    let override = 'http://mockurl:8100/';
    let args = Object.assign({}, fakeConstructorArgs);
    args.webDriverAgentUrl = override;
    let agent = new WebDriverAgent({}, args);
    let wdaStub = sinon.stub(agent, 'getStatus');
    wdaStub.callsFake(function () {
      return {build: 'data'};
    });

    await agent.launch('sessionId').should.eventually.eql({build: 'data'});
    agent.url.href.should.eql(override);
    wdaStub.reset();
  });
});

describe('get url', function () {
  it('should use default WDA listening url', function () {
    const args = Object.assign({}, fakeConstructorArgs);
    const agent = new WebDriverAgent({}, args);
    agent.url.href.should.eql('http://localhost:8100/');
  });
  it('should use default WDA listening url with emply base url', function () {
    const wdaLocalPort = '9100';
    const wdaBaseUrl = '';

    const args = Object.assign({}, fakeConstructorArgs);
    args.wdaBaseUrl = wdaBaseUrl;
    args.wdaLocalPort = wdaLocalPort;

    const agent = new WebDriverAgent({}, args);
    agent.url.href.should.eql('http://localhost:9100/');
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
    wda.webDriverAgentUrl.should.equal('http://localhost:8100/');
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
    wda.webDriverAgentUrl.should.equal('http://localhost:8100/');
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

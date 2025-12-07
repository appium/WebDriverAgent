import { getXctestrunFilePath, getAdditionalRunContent, getXctestrunFileName } from '../../lib/utils';
import { PLATFORM_NAME_IOS, PLATFORM_NAME_TVOS } from '../../lib/constants';
import { fs } from '@appium/support';
import path from 'path';
import { fail } from 'assert';
import { arch } from 'os';
import sinon from 'sinon';

function get_arch() {
  return arch() === 'arm64' ? 'arm64' : 'x86_64';
}

describe('utils', function () {
  let chai;

  before(async function() {
    chai = await import('chai');
    const chaiAsPromised = await import('chai-as-promised');

    chai.should();
    chai.use(chaiAsPromised.default);
  });

  describe('#getXctestrunFilePath', function () {
    const platformVersion = '12.0';
    const sdkVersion = '12.2';
    const udid = 'xxxxxyyyyyyzzzzzz';
    const bootstrapPath = 'path/to/data';
    const platformName = PLATFORM_NAME_IOS;
    let sandbox;

    beforeEach(function () {
      sandbox = sinon.createSandbox();
    });

    afterEach(function () {
      sandbox.restore();
    });

    it('should return sdk based path with udid', async function () {
      sandbox.stub(fs, 'exists')
        .withArgs(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`))
        .resolves(true);
      sandbox.stub(fs, 'copyFile');
      const deviceInfo = {isRealDevice: true, udid, platformVersion, platformName};
      await getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath)
        .should.eventually.equal(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`));
      sandbox.assert.notCalled(fs.copyFile);
    });

    it('should return sdk based path without udid, copy them', async function () {
      const existsStub = sandbox.stub(fs, 'exists');
      existsStub.withArgs(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`)).resolves(false);
      existsStub.withArgs(path.resolve(`${bootstrapPath}/WebDriverAgentRunner_iphoneos${sdkVersion}-arm64.xctestrun`)).resolves(true);
      sandbox.stub(fs, 'copyFile')
        .withArgs(
          path.resolve(`${bootstrapPath}/WebDriverAgentRunner_iphoneos${sdkVersion}-arm64.xctestrun`),
          path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`)
        )
        .resolves();
      const deviceInfo = {isRealDevice: true, udid, platformVersion};
      await getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath)
        .should.eventually.equal(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`));
    });

    it('should return platform based path', async function () {
      const existsStub = sandbox.stub(fs, 'exists');
      existsStub.withArgs(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`)).resolves(false);
      existsStub.withArgs(path.resolve(`${bootstrapPath}/WebDriverAgentRunner_iphonesimulator${sdkVersion}-${get_arch()}.xctestrun`)).resolves(false);
      existsStub.withArgs(path.resolve(`${bootstrapPath}/${udid}_${platformVersion}.xctestrun`)).resolves(true);
      sandbox.stub(fs, 'copyFile');
      const deviceInfo = {isRealDevice: false, udid, platformVersion};
      await getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath)
        .should.eventually.equal(path.resolve(`${bootstrapPath}/${udid}_${platformVersion}.xctestrun`));
      sandbox.assert.notCalled(fs.copyFile);
    });

    it('should return platform based path without udid, copy them', async function () {
      const existsStub = sandbox.stub(fs, 'exists');
      existsStub.withArgs(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`)).resolves(false);
      existsStub.withArgs(path.resolve(`${bootstrapPath}/WebDriverAgentRunner_iphonesimulator${sdkVersion}-${get_arch()}.xctestrun`)).resolves(false);
      existsStub.withArgs(path.resolve(`${bootstrapPath}/${udid}_${platformVersion}.xctestrun`)).resolves(false);
      existsStub.withArgs(path.resolve(`${bootstrapPath}/WebDriverAgentRunner_iphonesimulator${platformVersion}-${get_arch()}.xctestrun`)).resolves(true);
      sandbox.stub(fs, 'copyFile')
        .withArgs(
          path.resolve(`${bootstrapPath}/WebDriverAgentRunner_iphonesimulator${platformVersion}-${get_arch()}.xctestrun`),
          path.resolve(`${bootstrapPath}/${udid}_${platformVersion}.xctestrun`)
        )
        .resolves();

      const deviceInfo = {isRealDevice: false, udid, platformVersion};
      await getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath)
        .should.eventually.equal(path.resolve(`${bootstrapPath}/${udid}_${platformVersion}.xctestrun`));
    });

    it('should raise an exception because of no files', async function () {
      const expected = path.resolve(`${bootstrapPath}/WebDriverAgentRunner_iphonesimulator${sdkVersion}-${get_arch()}.xctestrun`);
      sandbox.stub(fs, 'exists').resolves(false);

      const deviceInfo = {isRealDevice: false, udid, platformVersion};
      try {
        await getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath);
        fail();
      } catch (err) {
        err.message.should.equal(`If you are using 'useXctestrunFile' capability then you need to have a xctestrun file (expected: '${expected}')`);
      }
    });
  });

  describe('#getAdditionalRunContent', function () {
    it('should return ios format', function () {
      const wdaPort = getAdditionalRunContent(PLATFORM_NAME_IOS, 8000);
      wdaPort.WebDriverAgentRunner
        .EnvironmentVariables.USE_PORT
        .should.equal('8000');
    });

    it('should return tvos format', function () {
      const wdaPort = getAdditionalRunContent(PLATFORM_NAME_TVOS, '9000');
      wdaPort.WebDriverAgentRunner_tvOS
        .EnvironmentVariables.USE_PORT
        .should.equal('9000');
    });
  });

  describe('#getXctestrunFileName', function () {
    const platformVersion = '12.0';
    const udid = 'xxxxxyyyyyyzzzzzz';

    it('should return ios format, real device', function () {
      const platformName = 'iOs';
      const deviceInfo = {isRealDevice: true, udid, platformVersion, platformName};

      getXctestrunFileName(deviceInfo, '10.2.0').should.equal(
        'WebDriverAgentRunner_iphoneos10.2.0-arm64.xctestrun');
    });

    it('should return ios format, simulator', function () {
      const platformName = 'ios';
      const deviceInfo = {isRealDevice: false, udid, platformVersion, platformName};

      getXctestrunFileName(deviceInfo, '10.2.0').should.equal(
        `WebDriverAgentRunner_iphonesimulator10.2.0-${get_arch()}.xctestrun`);
    });

    it('should return tvos format, real device', function () {
      const platformName = 'tVos';
      const deviceInfo = {isRealDevice: true, udid, platformVersion, platformName};

      getXctestrunFileName(deviceInfo, '10.2.0').should.equal(
        'WebDriverAgentRunner_tvOS_appletvos10.2.0-arm64.xctestrun');
    });

    it('should return tvos format, simulator', function () {
      const platformName = 'tvOS';
      const deviceInfo = {isRealDevice: false, udid, platformVersion, platformName};

      getXctestrunFileName(deviceInfo, '10.2.0').should.equal(
        `WebDriverAgentRunner_tvOS_appletvsimulator10.2.0-${get_arch()}.xctestrun`);
    });
  });
});

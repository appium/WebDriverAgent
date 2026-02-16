import chai, {expect} from 'chai';
import chaiAsPromised from 'chai-as-promised';
import {getXctestrunFilePath, getAdditionalRunContent, getXctestrunFileName} from '../../lib/utils';
import {PLATFORM_NAME_IOS, PLATFORM_NAME_TVOS} from '../../lib/constants';
import {fs} from '@appium/support';
import path from 'node:path';
import {fail} from 'node:assert';
import {arch} from 'node:os';
import sinon from 'sinon';
import type {DeviceInfo} from '../../lib/types';

chai.use(chaiAsPromised);

function get_arch(): string {
  return arch() === 'arm64' ? 'arm64' : 'x86_64';
}

describe('utils', function () {
  describe('#getXctestrunFilePath', function () {
    const platformVersion = '12.0';
    const sdkVersion = '12.2';
    const udid = 'xxxxxyyyyyyzzzzzz';
    const bootstrapPath = 'path/to/data';
    const platformName = PLATFORM_NAME_IOS;
    let sandbox: sinon.SinonSandbox;

    beforeEach(function () {
      sandbox = sinon.createSandbox();
    });

    afterEach(function () {
      sandbox.restore();
    });

    it('should return sdk based path with udid', async function () {
      sandbox
        .stub(fs, 'exists')
        .withArgs(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`))
        .resolves(true);
      sandbox.stub(fs, 'copyFile');
      const deviceInfo: DeviceInfo = {isRealDevice: true, udid, platformVersion, platformName};
      await expect(getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath)).to.eventually.equal(
        path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`),
      );
      sandbox.assert.notCalled(fs.copyFile);
    });

    it('should return sdk based path without udid, copy them', async function () {
      const existsStub = sandbox.stub(fs, 'exists');
      existsStub
        .withArgs(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`))
        .resolves(false);
      existsStub
        .withArgs(
          path.resolve(
            `${bootstrapPath}/WebDriverAgentRunner_iphoneos${sdkVersion}-arm64.xctestrun`,
          ),
        )
        .resolves(true);
      sandbox
        .stub(fs, 'copyFile')
        .withArgs(
          path.resolve(
            `${bootstrapPath}/WebDriverAgentRunner_iphoneos${sdkVersion}-arm64.xctestrun`,
          ),
          path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`),
        )
        .resolves();
      const deviceInfo: DeviceInfo = {
        isRealDevice: true,
        udid,
        platformVersion,
        platformName: PLATFORM_NAME_IOS,
      };
      await expect(getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath)).to.eventually.equal(
        path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`),
      );
    });

    it('should return platform based path', async function () {
      const existsStub = sandbox.stub(fs, 'exists');
      existsStub
        .withArgs(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`))
        .resolves(false);
      existsStub
        .withArgs(
          path.resolve(
            `${bootstrapPath}/WebDriverAgentRunner_iphonesimulator${sdkVersion}-${get_arch()}.xctestrun`,
          ),
        )
        .resolves(false);
      existsStub
        .withArgs(path.resolve(`${bootstrapPath}/${udid}_${platformVersion}.xctestrun`))
        .resolves(true);
      sandbox.stub(fs, 'copyFile');
      const deviceInfo: DeviceInfo = {
        isRealDevice: false,
        udid,
        platformVersion,
        platformName: PLATFORM_NAME_IOS,
      };
      await expect(getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath)).to.eventually.equal(
        path.resolve(`${bootstrapPath}/${udid}_${platformVersion}.xctestrun`),
      );
      sandbox.assert.notCalled(fs.copyFile);
    });

    it('should return platform based path without udid, copy them', async function () {
      const existsStub = sandbox.stub(fs, 'exists');
      existsStub
        .withArgs(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`))
        .resolves(false);
      existsStub
        .withArgs(
          path.resolve(
            `${bootstrapPath}/WebDriverAgentRunner_iphonesimulator${sdkVersion}-${get_arch()}.xctestrun`,
          ),
        )
        .resolves(false);
      existsStub
        .withArgs(path.resolve(`${bootstrapPath}/${udid}_${platformVersion}.xctestrun`))
        .resolves(false);
      existsStub
        .withArgs(
          path.resolve(
            `${bootstrapPath}/WebDriverAgentRunner_iphonesimulator${platformVersion}-${get_arch()}.xctestrun`,
          ),
        )
        .resolves(true);
      sandbox
        .stub(fs, 'copyFile')
        .withArgs(
          path.resolve(
            `${bootstrapPath}/WebDriverAgentRunner_iphonesimulator${platformVersion}-${get_arch()}.xctestrun`,
          ),
          path.resolve(`${bootstrapPath}/${udid}_${platformVersion}.xctestrun`),
        )
        .resolves();

      const deviceInfo: DeviceInfo = {
        isRealDevice: false,
        udid,
        platformVersion,
        platformName: PLATFORM_NAME_IOS,
      };
      await expect(getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath)).to.eventually.equal(
        path.resolve(`${bootstrapPath}/${udid}_${platformVersion}.xctestrun`),
      );
    });

    it('should raise an exception because of no files', async function () {
      const expected = path.resolve(
        `${bootstrapPath}/WebDriverAgentRunner_iphonesimulator${sdkVersion}-${get_arch()}.xctestrun`,
      );
      sandbox.stub(fs, 'exists').resolves(false);

      const deviceInfo: DeviceInfo = {
        isRealDevice: false,
        udid,
        platformVersion,
        platformName: PLATFORM_NAME_IOS,
      };
      try {
        await getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath);
        fail();
      } catch (err: any) {
        expect(err.message).to.equal(
          `If you are using 'useXctestrunFile' capability then you need to have a xctestrun file (expected: '${expected}')`,
        );
      }
    });
  });

  describe('#getAdditionalRunContent', function () {
    it('should return ios format', function () {
      const wdaPort = getAdditionalRunContent(PLATFORM_NAME_IOS, 8000);
      expect(wdaPort.WebDriverAgentRunner.EnvironmentVariables.USE_PORT).to.equal('8000');
    });

    it('should return tvos format', function () {
      const wdaPort = getAdditionalRunContent(PLATFORM_NAME_TVOS, '9000');
      expect(wdaPort.WebDriverAgentRunner_tvOS.EnvironmentVariables.USE_PORT).to.equal('9000');
    });
  });

  describe('#getXctestrunFileName', function () {
    const platformVersion = '12.0';
    const udid = 'xxxxxyyyyyyzzzzzz';

    it('should return ios format, real device', function () {
      const platformName = 'iOs';
      const deviceInfo: DeviceInfo = {isRealDevice: true, udid, platformVersion, platformName};

      expect(getXctestrunFileName(deviceInfo, '10.2.0')).to.equal(
        'WebDriverAgentRunner_iphoneos10.2.0-arm64.xctestrun',
      );
    });

    it('should return ios format, simulator', function () {
      const platformName = 'ios';
      const deviceInfo: DeviceInfo = {isRealDevice: false, udid, platformVersion, platformName};

      expect(getXctestrunFileName(deviceInfo, '10.2.0')).to.equal(
        `WebDriverAgentRunner_iphonesimulator10.2.0-${get_arch()}.xctestrun`,
      );
    });

    it('should return tvos format, real device', function () {
      const platformName = 'tVos';
      const deviceInfo: DeviceInfo = {isRealDevice: true, udid, platformVersion, platformName};

      expect(getXctestrunFileName(deviceInfo, '10.2.0')).to.equal(
        'WebDriverAgentRunner_tvOS_appletvos10.2.0-arm64.xctestrun',
      );
    });

    it('should return tvos format, simulator', function () {
      const platformName = 'tvOS';
      const deviceInfo: DeviceInfo = {isRealDevice: false, udid, platformVersion, platformName};

      expect(getXctestrunFileName(deviceInfo, '10.2.0')).to.equal(
        `WebDriverAgentRunner_tvOS_appletvsimulator10.2.0-${get_arch()}.xctestrun`,
      );
    });
  });
});

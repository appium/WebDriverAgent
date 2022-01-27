import { getXctestrunFilePath, getAdditionalRunContent, getXctestrunFileName } from '../../lib/utils';
import { PLATFORM_NAME_IOS, PLATFORM_NAME_TVOS } from '../../lib/constants';
import chai from 'chai';
import chaiAsPromised from 'chai-as-promised';
import { withMocks } from '@appium/test-support';
import { fs } from '@appium/support';
import path from 'path';
import { fail } from 'assert';

chai.should();
chai.use(chaiAsPromised);

describe('utils', function () {
  describe('#getXctestrunFilePath', withMocks({fs}, function (mocks) {
    const platformVersion = '12.0';
    const sdkVersion = '12.2';
    const udid = 'xxxxxyyyyyyzzzzzz';
    const bootstrapPath = 'path/to/data';
    const platformName = PLATFORM_NAME_IOS;

    afterEach(function () {
      mocks.verify();
    });

    it('should return sdk based path with udid', async function () {
      mocks.fs.expects('exists')
        .withExactArgs(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`))
        .returns(true);
      mocks.fs.expects('copyFile')
        .never();
      const deviceInfo = {isRealDevice: true, udid, platformVersion, platformName};
      await getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath)
        .should.eventually.equal(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`));
    });

    it('should return sdk based path without udid, copy them', async function () {
      mocks.fs.expects('exists')
        .withExactArgs(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`))
        .returns(false);
      mocks.fs.expects('exists')
        .withExactArgs(path.resolve(`${bootstrapPath}/WebDriverAgentRunner_iphoneos${sdkVersion}-arm64.xctestrun`))
        .returns(true);
      mocks.fs.expects('copyFile')
        .withExactArgs(
          path.resolve(`${bootstrapPath}/WebDriverAgentRunner_iphoneos${sdkVersion}-arm64.xctestrun`),
          path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`)
        )
        .returns(true);
      const deviceInfo = {isRealDevice: true, udid, platformVersion};
      await getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath)
        .should.eventually.equal(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`));
    });

    it('should return platform based path', async function () {
      mocks.fs.expects('exists')
        .withExactArgs(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`))
        .returns(false);
      mocks.fs.expects('exists')
        .withExactArgs(path.resolve(`${bootstrapPath}/WebDriverAgentRunner_iphonesimulator${sdkVersion}-x86_64.xctestrun`))
        .returns(false);
      mocks.fs.expects('exists')
        .withExactArgs(path.resolve(`${bootstrapPath}/${udid}_${platformVersion}.xctestrun`))
        .returns(true);
      mocks.fs.expects('copyFile')
        .never();
      const deviceInfo = {isRealDevice: false, udid, platformVersion};
      await getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath)
        .should.eventually.equal(path.resolve(`${bootstrapPath}/${udid}_${platformVersion}.xctestrun`));
    });

    it('should return platform based path without udid, copy them', async function () {
      mocks.fs.expects('exists')
        .withExactArgs(path.resolve(`${bootstrapPath}/${udid}_${sdkVersion}.xctestrun`))
        .returns(false);
      mocks.fs.expects('exists')
        .withExactArgs(path.resolve(`${bootstrapPath}/WebDriverAgentRunner_iphonesimulator${sdkVersion}-x86_64.xctestrun`))
        .returns(false);
      mocks.fs.expects('exists')
        .withExactArgs(path.resolve(`${bootstrapPath}/${udid}_${platformVersion}.xctestrun`))
        .returns(false);
      mocks.fs.expects('exists')
        .withExactArgs(path.resolve(`${bootstrapPath}/WebDriverAgentRunner_iphonesimulator${platformVersion}-x86_64.xctestrun`))
        .returns(true);
      mocks.fs.expects('copyFile')
        .withExactArgs(
          path.resolve(`${bootstrapPath}/WebDriverAgentRunner_iphonesimulator${platformVersion}-x86_64.xctestrun`),
          path.resolve(`${bootstrapPath}/${udid}_${platformVersion}.xctestrun`)
        )
        .returns(true);

      const deviceInfo = {isRealDevice: false, udid, platformVersion};
      await getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath)
        .should.eventually.equal(path.resolve(`${bootstrapPath}/${udid}_${platformVersion}.xctestrun`));
    });

    it('should raise an exception because of no files', async function () {
      const expected = path.resolve(`${bootstrapPath}/WebDriverAgentRunner_iphonesimulator${sdkVersion}-x86_64.xctestrun`);
      mocks.fs.expects('exists').exactly(4).returns(false);

      const deviceInfo = {isRealDevice: false, udid, platformVersion};
      try {
        await getXctestrunFilePath(deviceInfo, sdkVersion, bootstrapPath);
        fail();
      } catch (err) {
        err.message.should.equal(`If you are using 'useXctestrunFile' capability then you need to have a xctestrun file (expected: '${expected}')`);
      }
    });
  }));

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
        'WebDriverAgentRunner_iphonesimulator10.2.0-x86_64.xctestrun');
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
        'WebDriverAgentRunner_tvOS_appletvsimulator10.2.0-x86_64.xctestrun');
    });
  });
});

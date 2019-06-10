import { checkForDependencies, BOOTSTRAP_PATH } from '..';
import chai from 'chai';
import chaiAsPromised from 'chai-as-promised';
import * as teen_process from 'teen_process';
import { withMocks } from 'appium-test-support';
import { fs } from 'appium-support';
import * as utils from '../lib/utils';


chai.should();
chai.use(chaiAsPromised);


function mockPassingResourceCreation (mocks) {
  mocks.fs.expects('hasAccess').twice()
    .onFirstCall().returns(false)
    .onSecondCall().returns(false);
  mocks.fs.expects('mkdir')
    .withExactArgs(`${BOOTSTRAP_PATH}/Resources`);
  mocks.fs.expects('mkdir')
    .withExactArgs(`${BOOTSTRAP_PATH}/Resources/WebDriverAgent.bundle`);
}

function mockSkippingCarthageRun (mocks) {
  mocks.fs.expects('which').once().returns(true);
  mocks.utils.expects('fileCompare').once()
    .onFirstCall().returns(true);
  mocks.teen_process.expects('exec').never();
}

describe('webdriveragent utils', function () {
  describe('checkForDependencies', withMocks({teen_process, fs, utils}, (mocks) => {
    afterEach(function () {
      mocks.verify();
    });
    it('should not run script if Carthage directory already present', async function () {
      mocks.fs.expects('which').once().returns(true);
      mocks.utils.expects('fileCompare').once()
        .onFirstCall().returns(true);
      mocks.teen_process.expects('exec').never();

      mockPassingResourceCreation(mocks);

      await checkForDependencies();
    });
    it('should delete Carthage folder and throw error on script error', async function () {
      mocks.fs.expects('which').once().returns(true);
      mocks.utils.expects('fileCompare').once()
        .onFirstCall().returns(false);
      mocks.teen_process.expects('exec')
        .once().withArgs('xcrun', ['simctl', 'list', 'devices', '-j'])
        .returns({stdout: `{"devices" : {}}`});
      mocks.teen_process.expects('exec')
        .once().withArgs('carthage', ['bootstrap', '--platform', 'iOS'])
        .throws({stdout: '', stderr: '', message: 'Carthage failure'});

      await checkForDependencies().should.eventually.be.rejectedWith(/Carthage failure/);
    });
    it('should create Resources folder if not already there', async function () {
      mockSkippingCarthageRun(mocks);

      mocks.fs.expects('hasAccess').twice()
        .onFirstCall().returns(false)
        .onSecondCall().returns(true);
      mocks.fs.expects('mkdir')
        .withExactArgs(`${BOOTSTRAP_PATH}/Resources`);

      await checkForDependencies();
    });
    it('should create WDA bundle if not already there', async function () {
      mockSkippingCarthageRun(mocks);

      mocks.fs.expects('hasAccess').twice()
        .onFirstCall().returns(true)
        .onSecondCall().returns(false);
      mocks.fs.expects('mkdir')
        .withExactArgs(`${BOOTSTRAP_PATH}/Resources/WebDriverAgent.bundle`);

      await checkForDependencies();
    });
  }));
});

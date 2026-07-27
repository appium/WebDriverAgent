import releaseConfig from '@appium/semantic-release-config';

export default releaseConfig({
  githubAssets: [
    'WebDriverAgentRunner-Runner.zip',
    'WebDriverAgentRunner_tvOS-Runner.zip',
    'WebDriverAgentRunner-Build-Sim-arm64.zip',
    'WebDriverAgentRunner-Build-Sim-x86_64.zip',
    'WebDriverAgentRunner_tvOS-Build-Sim-arm64.zip',
    'WebDriverAgentRunner_tvOS-Build-Sim-x86_64.zip',
  ],
});

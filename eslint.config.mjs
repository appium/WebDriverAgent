import appiumConfig from '@appium/eslint-config-appium-ts';

export default [
  ...appiumConfig,
  {
    ignores: [
      'Configurations/**',
      'Fastlane/**',
      'PrivateHeaders/**',
      'WebDriverAgent*/**'
    ],
  },
];

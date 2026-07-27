import appiumConfig, {defineConfig, ignorePatterns} from '@appium/oxc-config/oxfmt';

export default defineConfig({
  ...appiumConfig,
  ignorePatterns: [...ignorePatterns, 'Configurations/**', 'Fastlane/**', 'PrivateHeaders/**', 'WebDriverAgent*/**'],
});

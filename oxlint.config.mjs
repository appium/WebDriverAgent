import appiumConfig, {defineConfig, ignorePatterns} from '@appium/oxc-config/oxlint';

export default defineConfig({
  extends: [appiumConfig],
  ignorePatterns: [...ignorePatterns, 'Configurations/**', 'Fastlane/**', 'PrivateHeaders/**', 'WebDriverAgent*/**'],
});

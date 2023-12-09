## [5.15.4](https://github.com/appium/WebDriverAgent/compare/v5.15.3...v5.15.4) (2023-12-07)


### Bug Fixes

* set appearance in iOS 17+ ([#818](https://github.com/appium/WebDriverAgent/issues/818)) ([357a2cb](https://github.com/appium/WebDriverAgent/commit/357a2cbca106daf42bc892b251802bfa00895598))

## [5.15.3](https://github.com/appium/WebDriverAgent/compare/v5.15.2...v5.15.3) (2023-11-24)


### Miscellaneous Chores

* Make xcodebuild error message more helpful ([#816](https://github.com/appium/WebDriverAgent/issues/816)) ([2d7fc03](https://github.com/appium/WebDriverAgent/commit/2d7fc0370b30e5e3adc9a13002fa95f607c4c160))

## [5.15.2](https://github.com/appium/WebDriverAgent/compare/v5.15.1...v5.15.2) (2023-11-23)


### Bug Fixes

* fix run test ci ([#814](https://github.com/appium/WebDriverAgent/issues/814)) ([014d04d](https://github.com/appium/WebDriverAgent/commit/014d04df956e47fef67938b089511e80d344f007))


### Miscellaneous Chores

* a dummy commit to check a package release ([08388fd](https://github.com/appium/WebDriverAgent/commit/08388fd602ee9d588a8780e8d141d748813782ed))

## [5.15.1](https://github.com/appium/WebDriverAgent/compare/v5.15.0...v5.15.1) (2023-11-16)


### Bug Fixes

* Content-Type of the MJPEG server ([b4704da](https://github.com/appium/WebDriverAgent/commit/b4704dafc4567e1f0dc8675facfc48a195aae4bf))


### Code Refactoring

* Optimize screenshots preprocessing ([#812](https://github.com/appium/WebDriverAgent/issues/812)) ([0b41757](https://github.com/appium/WebDriverAgent/commit/0b41757c0d21004afab32860b4e510d4bc426018))

## [5.15.0](https://github.com/appium/WebDriverAgent/compare/v5.14.0...v5.15.0) (2023-11-16)


### Features

* Add element attributes to the performAccessibilityAudit output ([#808](https://github.com/appium/WebDriverAgent/issues/808)) ([0d7e4a6](https://github.com/appium/WebDriverAgent/commit/0d7e4a697adb7355279583eaa05118f396056e6f))

## [5.14.0](https://github.com/appium/WebDriverAgent/compare/v5.13.3...v5.14.0) (2023-11-10)


### Features

* use khidusage_keyboardclear to `clear` for iOS/iPad as the 1st attempt, tune tvOS ([#811](https://github.com/appium/WebDriverAgent/issues/811)) ([dd093ea](https://github.com/appium/WebDriverAgent/commit/dd093ea0b7209c3d2f3d0b1fa7f3a7b58507dd2d))

## [5.13.3](https://github.com/appium/WebDriverAgent/compare/v5.13.2...v5.13.3) (2023-11-10)


### Bug Fixes

* unrecognized selector sent to instance 0x2829adb20 error in clear ([#809](https://github.com/appium/WebDriverAgent/issues/809)) ([79832bc](https://github.com/appium/WebDriverAgent/commit/79832bc6c69e289091fbbb97aee6a1f1d17ca4c3))

## [5.13.2](https://github.com/appium/WebDriverAgent/compare/v5.13.1...v5.13.2) (2023-11-06)


### Miscellaneous Chores

* **deps-dev:** bump @types/sinon from 10.0.20 to 17.0.0 ([#805](https://github.com/appium/WebDriverAgent/issues/805)) ([824f74c](https://github.com/appium/WebDriverAgent/commit/824f74c69769973858350bd5db0061510c546b09))

## [5.13.1](https://github.com/appium/WebDriverAgent/compare/v5.13.0...v5.13.1) (2023-11-01)


### Miscellaneous Chores

* **deps:** bump asyncbox from 2.9.4 to 3.0.0 ([#803](https://github.com/appium/WebDriverAgent/issues/803)) ([0f2305d](https://github.com/appium/WebDriverAgent/commit/0f2305d2559dc0807d7df0d0e06f7fc3c549701c))

## [5.13.0](https://github.com/appium/WebDriverAgent/compare/v5.12.3...v5.13.0) (2023-10-31)


### Features

* Add "elementDescription" property to audit issues containing the debug description of an element ([#802](https://github.com/appium/WebDriverAgent/issues/802)) ([9925af4](https://github.com/appium/WebDriverAgent/commit/9925af44ec5fbfb66e6f034dfd93a6c25de48661))

## [5.12.3](https://github.com/appium/WebDriverAgent/compare/v5.12.2...v5.12.3) (2023-10-31)


### Miscellaneous Chores

* Return better error on WDA startup timeout ([#801](https://github.com/appium/WebDriverAgent/issues/801)) ([796d5e7](https://github.com/appium/WebDriverAgent/commit/796d5e743676b174221e27e739a0164f4b91533c))

## [5.12.2](https://github.com/appium/WebDriverAgent/compare/v5.12.1...v5.12.2) (2023-10-29)


### Miscellaneous Chores

* return operation error in `handleKeyboardInput` ([#799](https://github.com/appium/WebDriverAgent/issues/799)) ([247ace6](https://github.com/appium/WebDriverAgent/commit/247ace68f373c09054fabc3be088061089946806))

## [5.12.1](https://github.com/appium/WebDriverAgent/compare/v5.12.0...v5.12.1) (2023-10-28)


### Bug Fixes

* when 0 is given for handleKeyboardInput ([#798](https://github.com/appium/WebDriverAgent/issues/798)) ([58ebe8e](https://github.com/appium/WebDriverAgent/commit/58ebe8eb52966963ee30a5c066beb3bf9fed3161))

## [5.12.0](https://github.com/appium/WebDriverAgent/compare/v5.11.7...v5.12.0) (2023-10-26)


### Features

* Add an endpoint for keyboard input ([#797](https://github.com/appium/WebDriverAgent/issues/797)) ([aaf70c9](https://github.com/appium/WebDriverAgent/commit/aaf70c9196e4dcb2073da151cda23b2b221d4dae))

## [5.11.7](https://github.com/appium/WebDriverAgent/compare/v5.11.6...v5.11.7) (2023-10-25)


### Miscellaneous Chores

* **deps-dev:** bump @typescript-eslint/eslint-plugin from 5.62.0 to 6.9.0 ([#796](https://github.com/appium/WebDriverAgent/issues/796)) ([dabf141](https://github.com/appium/WebDriverAgent/commit/dabf141acd3186b1c27231ef52826fa42208c980))

## [5.11.6](https://github.com/appium/WebDriverAgent/compare/v5.11.5...v5.11.6) (2023-10-25)


### Miscellaneous Chores

* disable debugger for wda ([#768](https://github.com/appium/WebDriverAgent/issues/768)) ([e2f4405](https://github.com/appium/WebDriverAgent/commit/e2f4405a3449f1f4d390eae06bf91a220e81b58b))

## [5.11.5](https://github.com/appium/WebDriverAgent/compare/v5.11.4...v5.11.5) (2023-10-23)


### Miscellaneous Chores

* **deps-dev:** bump eslint-config-prettier from 8.10.0 to 9.0.0 ([#791](https://github.com/appium/WebDriverAgent/issues/791)) ([f130961](https://github.com/appium/WebDriverAgent/commit/f130961f189f2746d4a2b0a18105fc10203312ca))
* **deps-dev:** bump lint-staged from 14.0.1 to 15.0.2 ([#792](https://github.com/appium/WebDriverAgent/issues/792)) ([440279d](https://github.com/appium/WebDriverAgent/commit/440279d4f6d069e440180faf4bee8e5dc1758787))
* **deps-dev:** bump semantic-release from 21.1.2 to 22.0.5 ([#781](https://github.com/appium/WebDriverAgent/issues/781)) ([a967183](https://github.com/appium/WebDriverAgent/commit/a96718308dbd6b13feb30e6ce8f01a7d9b74b146))

## [5.11.4](https://github.com/appium/WebDriverAgent/compare/v5.11.3...v5.11.4) (2023-10-23)


### Miscellaneous Chores

* **deps-dev:** bump sinon from 16.1.3 to 17.0.0 ([#795](https://github.com/appium/WebDriverAgent/issues/795)) ([4921899](https://github.com/appium/WebDriverAgent/commit/4921899d96800dbcd59a9c27ba793ad16d0c715b))

## [5.11.3](https://github.com/appium/WebDriverAgent/compare/v5.11.2...v5.11.3) (2023-10-21)


### Miscellaneous Chores

* use PRODUCT_BUNDLE_IDENTIFIER to info.plist ([#794](https://github.com/appium/WebDriverAgent/issues/794)) ([543c498](https://github.com/appium/WebDriverAgent/commit/543c49860d2d35148bcbaa33e14d3e1dab058cef))

## [5.11.2](https://github.com/appium/WebDriverAgent/compare/v5.11.1...v5.11.2) (2023-10-19)


### Miscellaneous Chores

* Use latest teen_process types ([895cdfc](https://github.com/appium/WebDriverAgent/commit/895cdfc1a316117bb7c8b5be0265b439c1e911bc))

## [5.11.1](https://github.com/appium/WebDriverAgent/compare/v5.11.0...v5.11.1) (2023-10-19)


### Miscellaneous Chores

* Use latest types version ([123eefb](https://github.com/appium/WebDriverAgent/commit/123eefba5e5e30100cb3cdff09a516179f78afe7))

## [5.11.0](https://github.com/appium/WebDriverAgent/compare/v5.10.1...v5.11.0) (2023-10-05)


### Features

* Add /calibrate endpoint ([#785](https://github.com/appium/WebDriverAgent/issues/785)) ([ae1603a](https://github.com/appium/WebDriverAgent/commit/ae1603a3b5b5c4828ed4959c63d6274254f832a2))

## [5.10.1](https://github.com/appium/WebDriverAgent/compare/v5.10.0...v5.10.1) (2023-10-05)


### Miscellaneous Chores

* Remove the hardcoded keyboard wait delay from handleKeys ([#784](https://github.com/appium/WebDriverAgent/issues/784)) ([f043d67](https://github.com/appium/WebDriverAgent/commit/f043d67dd90fbfca00b8cf53ccae63dbd67fa150))

## [5.10.0](https://github.com/appium/WebDriverAgent/compare/v5.9.1...v5.10.0) (2023-09-25)


### Features

* remove test frameworks in Frameworks and add device local references as rpath for real devices ([#780](https://github.com/appium/WebDriverAgent/issues/780)) ([ae6c842](https://github.com/appium/WebDriverAgent/commit/ae6c842f3c4e7deb51fcc7a1a1045d4eeede69fd))

## [5.9.1](https://github.com/appium/WebDriverAgent/compare/v5.9.0...v5.9.1) (2023-09-22)


### Bug Fixes

* Provide signing arguments as command line parameters ([#779](https://github.com/appium/WebDriverAgent/issues/779)) ([51ba527](https://github.com/appium/WebDriverAgent/commit/51ba527b6cde3773ebcd5323cfa7e0890b2563aa))

## [5.9.0](https://github.com/appium/WebDriverAgent/compare/v5.8.7...v5.9.0) (2023-09-22)


### Features

* do not get active process information in a new session request ([#774](https://github.com/appium/WebDriverAgent/issues/774)) ([2784ce4](https://github.com/appium/WebDriverAgent/commit/2784ce440f8b5ab9710db08d9ffda704697ac07c))

## [5.8.7](https://github.com/appium/WebDriverAgent/compare/v5.8.6...v5.8.7) (2023-09-22)


### Miscellaneous Chores

* tweak device in currentCapabilities ([#773](https://github.com/appium/WebDriverAgent/issues/773)) ([8481b02](https://github.com/appium/WebDriverAgent/commit/8481b02fc84de1147e1254ea7fd114f8735b0226))

## [5.8.6](https://github.com/appium/WebDriverAgent/compare/v5.8.5...v5.8.6) (2023-09-21)


### Miscellaneous Chores

* add log to leave it in the system log ([#772](https://github.com/appium/WebDriverAgent/issues/772)) ([012af21](https://github.com/appium/WebDriverAgent/commit/012af21383829397c7265daa0513829cc4e93aee))

## [5.8.5](https://github.com/appium/WebDriverAgent/compare/v5.8.4...v5.8.5) (2023-09-15)


### Miscellaneous Chores

* **deps-dev:** bump sinon from 15.2.0 to 16.0.0 ([#766](https://github.com/appium/WebDriverAgent/issues/766)) ([2ffd187](https://github.com/appium/WebDriverAgent/commit/2ffd187b2e8b3c1ed04537320179bdfe9f9635df))

## [5.8.4](https://github.com/appium/WebDriverAgent/compare/v5.8.3...v5.8.4) (2023-09-14)


### Miscellaneous Chores

* **deps-dev:** bump @types/teen_process from 2.0.0 to 2.0.1 ([#765](https://github.com/appium/WebDriverAgent/issues/765)) ([1af64b8](https://github.com/appium/WebDriverAgent/commit/1af64b8834371a3fdb3d0aab82fdfdeff6194555))

## [5.8.3](https://github.com/appium/WebDriverAgent/compare/v5.8.2...v5.8.3) (2023-09-01)


### Bug Fixes

* Address some typing-related issues ([#759](https://github.com/appium/WebDriverAgent/issues/759)) ([87e8704](https://github.com/appium/WebDriverAgent/commit/87e87044d6216513f755c5184d61514a76cb0179))

## [5.8.2](https://github.com/appium/WebDriverAgent/compare/v5.8.1...v5.8.2) (2023-08-28)


### Miscellaneous Chores

* **deps-dev:** bump conventional-changelog-conventionalcommits ([#757](https://github.com/appium/WebDriverAgent/issues/757)) ([a3047ea](https://github.com/appium/WebDriverAgent/commit/a3047ea70b7a9fd5ccb2a2c93b0964d7de609d38))

## [5.8.1](https://github.com/appium/WebDriverAgent/compare/v5.8.0...v5.8.1) (2023-08-25)


### Miscellaneous Chores

* **deps-dev:** bump semantic-release from 20.1.3 to 21.1.0 ([#754](https://github.com/appium/WebDriverAgent/issues/754)) ([d86d9a6](https://github.com/appium/WebDriverAgent/commit/d86d9a64ca75ad40273cfa10855f49b967d9fd95))

## [5.8.0](https://github.com/appium/WebDriverAgent/compare/v5.7.0...v5.8.0) (2023-08-24)


### Features

* Add wdHittable property ([#756](https://github.com/appium/WebDriverAgent/issues/756)) ([075298b](https://github.com/appium/WebDriverAgent/commit/075298b286c83ab5d4a2855e9e0bb915790b3f43))

## [5.7.0](https://github.com/appium/WebDriverAgent/compare/v5.6.2...v5.7.0) (2023-08-24)


### Features

* Switch babel to typescript ([#753](https://github.com/appium/WebDriverAgent/issues/753)) ([76a4c7f](https://github.com/appium/WebDriverAgent/commit/76a4c7f066e1895acbb153ab035d6a08604277e4))

## [5.6.2](https://github.com/appium/WebDriverAgent/compare/v5.6.1...v5.6.2) (2023-08-23)


### Miscellaneous Chores

* Remove unused glob dependency ([ee7655e](https://github.com/appium/WebDriverAgent/commit/ee7655e0a2aa39dd1f0c6d80d89065b4f34f264d))

## [5.6.1](https://github.com/appium/WebDriverAgent/compare/v5.6.0...v5.6.1) (2023-08-14)


### Miscellaneous Chores

* **deps-dev:** bump lint-staged from 13.3.0 to 14.0.0 ([#750](https://github.com/appium/WebDriverAgent/issues/750)) ([0b74bf5](https://github.com/appium/WebDriverAgent/commit/0b74bf5befaa6d87c93a5306beb690a5a0e1843d))

## [5.6.0](https://github.com/appium/WebDriverAgent/compare/v5.5.2...v5.6.0) (2023-07-15)


### Features

* apply shouldWaitForQuiescence for activate in /wda/apps/launch ([#739](https://github.com/appium/WebDriverAgent/issues/739)) ([#740](https://github.com/appium/WebDriverAgent/issues/740)) ([66ab695](https://github.com/appium/WebDriverAgent/commit/66ab695f9fa1850145a1d94ef15978b70bc1b032))

## [5.5.2](https://github.com/appium/WebDriverAgent/compare/v5.5.1...v5.5.2) (2023-07-07)


### Miscellaneous Chores

* **deps-dev:** bump prettier from 2.8.8 to 3.0.0 ([#735](https://github.com/appium/WebDriverAgent/issues/735)) ([15614d0](https://github.com/appium/WebDriverAgent/commit/15614d030975f2b1eac5919d2353bc015f194d4c))

## [5.5.1](https://github.com/appium/WebDriverAgent/compare/v5.5.0...v5.5.1) (2023-06-16)


### Bug Fixes

* Update strongbox API name ([4977032](https://github.com/appium/WebDriverAgent/commit/49770328aeeebacd76011ff1caf13d5b4ed71420))

## [5.5.0](https://github.com/appium/WebDriverAgent/compare/v5.4.1...v5.5.0) (2023-06-12)


### Features

* Add accessibility audit extension ([#727](https://github.com/appium/WebDriverAgent/issues/727)) ([78321dd](https://github.com/appium/WebDriverAgent/commit/78321dd3dafdb142eed136b48ec101f1daed50a4))

## [5.4.1](https://github.com/appium/WebDriverAgent/compare/v5.4.0...v5.4.1) (2023-06-09)


### Bug Fixes

* Return default testmanagerd version if the info is not available ([#728](https://github.com/appium/WebDriverAgent/issues/728)) ([e6e2dbd](https://github.com/appium/WebDriverAgent/commit/e6e2dbd86fc0c48ae146905f0e69a6223360e856))

## [5.4.0](https://github.com/appium/WebDriverAgent/compare/v5.3.3...v5.4.0) (2023-06-09)


### Features

* Drop older screenshoting APIs ([#721](https://github.com/appium/WebDriverAgent/issues/721)) ([4a08d7a](https://github.com/appium/WebDriverAgent/commit/4a08d7a843af6b93b378b4e3dc10f123d2e56359))


### Bug Fixes

* Streamline errors handling for async block calls ([#725](https://github.com/appium/WebDriverAgent/issues/725)) ([364b779](https://github.com/appium/WebDriverAgent/commit/364b7791393ffae9c048c5cac023e3e7d1813a14))

## [5.3.3](https://github.com/appium/WebDriverAgent/compare/v5.3.2...v5.3.3) (2023-06-08)


### Miscellaneous Chores

* Disable automatic screen recording by default ([#726](https://github.com/appium/WebDriverAgent/issues/726)) ([a070223](https://github.com/appium/WebDriverAgent/commit/a070223e0ef43be8dd54d16ee3e3b96603ad5f3a))

## [5.3.2](https://github.com/appium/WebDriverAgent/compare/v5.3.1...v5.3.2) (2023-06-07)


### Miscellaneous Chores

* **deps-dev:** bump conventional-changelog-conventionalcommits ([#723](https://github.com/appium/WebDriverAgent/issues/723)) ([b22f61e](https://github.com/appium/WebDriverAgent/commit/b22f61eda142ee6ec1db8c74a4788e0270ac7740))

## [5.3.1](https://github.com/appium/WebDriverAgent/compare/v5.3.0...v5.3.1) (2023-06-06)


### Bug Fixes

* remove Parameter of overriding method should be annotated with __attribute__((noescape)) ([#720](https://github.com/appium/WebDriverAgent/issues/720)) ([5f811ac](https://github.com/appium/WebDriverAgent/commit/5f811ac65ba3ac770e42bd7f8614815df8ec990f))

## [5.3.0](https://github.com/appium/WebDriverAgent/compare/v5.2.0...v5.3.0) (2023-05-22)


### Features

* Use strongbox to persist the previous version of the module ([#714](https://github.com/appium/WebDriverAgent/issues/714)) ([4611792](https://github.com/appium/WebDriverAgent/commit/4611792ee5d5d7f39d188b5ebc31017f436c5ace))

## [5.2.0](https://github.com/appium/WebDriverAgent/compare/v5.1.6...v5.2.0) (2023-05-20)


### Features

* Replace non-encodable characters in the resulting JSON ([#713](https://github.com/appium/WebDriverAgent/issues/713)) ([cdfae40](https://github.com/appium/WebDriverAgent/commit/cdfae408be0bcf6607f0ca4462925eed2c300f5e))

## [5.1.6](https://github.com/appium/WebDriverAgent/compare/v5.1.5...v5.1.6) (2023-05-18)


### Miscellaneous Chores

* **deps:** bump @appium/support from 3.1.11 to 4.0.0 ([#710](https://github.com/appium/WebDriverAgent/issues/710)) ([3e49523](https://github.com/appium/WebDriverAgent/commit/3e495230674a46db29ecea3b36c2ed0ea1bf2842))

## [5.1.5](https://github.com/appium/WebDriverAgent/compare/v5.1.4...v5.1.5) (2023-05-18)


### Miscellaneous Chores

* Drop obsolete workarounds for coordinates calculation ([#701](https://github.com/appium/WebDriverAgent/issues/701)) ([259f731](https://github.com/appium/WebDriverAgent/commit/259f7319305b15a3f541957d3ccaa3cb12c9e1a3))

## [5.1.4](https://github.com/appium/WebDriverAgent/compare/v5.1.3...v5.1.4) (2023-05-16)


### Bug Fixes

* Prevent freeze on launch/activate of a missing app ([#706](https://github.com/appium/WebDriverAgent/issues/706)) ([c4976e3](https://github.com/appium/WebDriverAgent/commit/c4976e3e99afa4d471bd39c3dccfc7d9f58d8bfc))

## [5.1.3](https://github.com/appium/WebDriverAgent/compare/v5.1.2...v5.1.3) (2023-05-16)


### Bug Fixes

* Revert "fix: Assert app is installed before launching or activating it ([#704](https://github.com/appium/WebDriverAgent/issues/704))" ([#705](https://github.com/appium/WebDriverAgent/issues/705)) ([00baeb2](https://github.com/appium/WebDriverAgent/commit/00baeb2045b9aac98d27fe2e96cedce0dde5e8be))

## [5.1.2](https://github.com/appium/WebDriverAgent/compare/v5.1.1...v5.1.2) (2023-05-15)


### Miscellaneous Chores

* remove code for old os versions ([#694](https://github.com/appium/WebDriverAgent/issues/694)) ([4a9faa5](https://github.com/appium/WebDriverAgent/commit/4a9faa5f85e0615c18a5f35090335bdbc7d56ebe))

## [5.1.1](https://github.com/appium/WebDriverAgent/compare/v5.1.0...v5.1.1) (2023-05-15)


### Bug Fixes

* Assert app is installed before launching or activating it ([#704](https://github.com/appium/WebDriverAgent/issues/704)) ([94e5c51](https://github.com/appium/WebDriverAgent/commit/94e5c51bce1d4518418e999b4ac466cd46ca3bc3))

## [5.1.0](https://github.com/appium/WebDriverAgent/compare/v5.0.0...v5.1.0) (2023-05-14)


### Features

* Add a possibility to provide a target picker value ([#699](https://github.com/appium/WebDriverAgent/issues/699)) ([fc76aee](https://github.com/appium/WebDriverAgent/commit/fc76aeecb087429974b7b52b725173186e6f0246))


### Code Refactoring

* Remove obsolete coordinate calculation workarounds needed for older xCode SDKs ([#698](https://github.com/appium/WebDriverAgent/issues/698)) ([025b42c](https://github.com/appium/WebDriverAgent/commit/025b42c8a34ff0beba4379f4cb0c1d79d2b222ed))

## [5.0.0](https://github.com/appium/WebDriverAgent/compare/v4.15.1...v5.0.0) (2023-05-14)


### ⚠ BREAKING CHANGES

* The minimum supported xCode/iOS version is now 13/15.0

### Code Refactoring

* Drop workarounds for legacy iOS versions ([#696](https://github.com/appium/WebDriverAgent/issues/696)) ([bb562b9](https://github.com/appium/WebDriverAgent/commit/bb562b96db6aad476970ef7bd352cb8df4f1e6c2))

## [4.15.1](https://github.com/appium/WebDriverAgent/compare/v4.15.0...v4.15.1) (2023-05-06)


### Performance Improvements

* tune webDriverAgentUrl case by skiping xcodebuild stuff ([#691](https://github.com/appium/WebDriverAgent/issues/691)) ([d8f1457](https://github.com/appium/WebDriverAgent/commit/d8f1457b591b2dd00040f8336c1a7a728af871d2))

## [4.15.0](https://github.com/appium/WebDriverAgent/compare/v4.14.0...v4.15.0) (2023-05-04)


### Features

* Make isFocused attribute available for iOS elements ([#692](https://github.com/appium/WebDriverAgent/issues/692)) ([0ec74ce](https://github.com/appium/WebDriverAgent/commit/0ec74ce32c817a5884228ccb2ec31f0a5a4de9c3))

## [4.14.0](https://github.com/appium/WebDriverAgent/compare/v4.13.2...v4.14.0) (2023-05-02)


### Features

* start wda process via Xctest in a real device ([#687](https://github.com/appium/WebDriverAgent/issues/687)) ([e1c0f83](https://github.com/appium/WebDriverAgent/commit/e1c0f836a68ad2efbedfc77343794d0d97ef6090))

## [4.13.2](https://github.com/appium/WebDriverAgent/compare/v4.13.1...v4.13.2) (2023-04-28)


### Miscellaneous Chores

* add withoutSession for pasteboard for debug ([#688](https://github.com/appium/WebDriverAgent/issues/688)) ([edcbf9e](https://github.com/appium/WebDriverAgent/commit/edcbf9e6af903c6f490ca90ff915497ad53bb8b5))

## [4.13.1](https://github.com/appium/WebDriverAgent/compare/v4.13.0...v4.13.1) (2023-04-04)


### Bug Fixes

* Fixed Xpath lookup for Xcode 14.3 ([#681](https://github.com/appium/WebDriverAgent/issues/681)) ([3e0b191](https://github.com/appium/WebDriverAgent/commit/3e0b1914f87585ed69ba20d960502eabb058941c))

## [4.13.0](https://github.com/appium/WebDriverAgent/compare/v4.12.2...v4.13.0) (2023-02-23)


### Features

* Increase Xpath Lookup Performance ([#666](https://github.com/appium/WebDriverAgent/issues/666)) ([1696f4b](https://github.com/appium/WebDriverAgent/commit/1696f4bb879152ef04408940849708654072c797))

## [4.12.2](https://github.com/appium/WebDriverAgent/compare/v4.12.1...v4.12.2) (2023-02-22)


### Miscellaneous Chores

* Make sure the test is never going to be unexpectedly interrupted ([#664](https://github.com/appium/WebDriverAgent/issues/664)) ([cafe47e](https://github.com/appium/WebDriverAgent/commit/cafe47e9bea9649a0e9b4a2b96ca44434bbac411))

## [4.12.1](https://github.com/appium/WebDriverAgent/compare/v4.12.0...v4.12.1) (2023-02-20)


### Bug Fixes

* Return null if no simulated location has been previously set ([#663](https://github.com/appium/WebDriverAgent/issues/663)) ([6a5c48b](https://github.com/appium/WebDriverAgent/commit/6a5c48bd2ffc43c0f0d9bf781671bbcf171f9375))

## [4.12.0](https://github.com/appium/WebDriverAgent/compare/v4.11.0...v4.12.0) (2023-02-20)


### Features

* Add support of the simulated geolocation setting ([#662](https://github.com/appium/WebDriverAgent/issues/662)) ([ebb9e60](https://github.com/appium/WebDriverAgent/commit/ebb9e60d56c0e0db9f509437ed639a3a39f6011b))

## [4.11.0](https://github.com/appium/WebDriverAgent/compare/v4.10.24...v4.11.0) (2023-02-19)


### Features

* Add openUrl handler available since Xcode 14.3 ([#661](https://github.com/appium/WebDriverAgent/issues/661)) ([bee564e](https://github.com/appium/WebDriverAgent/commit/bee564e8c6b975aff07fd1244583f0727a0f5470))

## [4.10.24](https://github.com/appium/WebDriverAgent/compare/v4.10.23...v4.10.24) (2023-02-17)


### Bug Fixes

* Catch unexpected exceptions thrown by the alerts monitor ([#660](https://github.com/appium/WebDriverAgent/issues/660)) ([aa22555](https://github.com/appium/WebDriverAgent/commit/aa22555f0dcf98de43c95cb20be73e911a97741e))

## [4.10.23](https://github.com/appium/WebDriverAgent/compare/v4.10.22...v4.10.23) (2023-02-05)


### Miscellaneous Chores

* bundle:tv for tvOS ([#657](https://github.com/appium/WebDriverAgent/issues/657)) ([9d2d047](https://github.com/appium/WebDriverAgent/commit/9d2d047fba57a33787c66a1e8a8449b9538c67be))

## [4.10.22](https://github.com/appium/WebDriverAgent/compare/v4.10.21...v4.10.22) (2023-01-30)


### Bug Fixes

* Pull defaultAdditionalRequestParameters dynamically ([#658](https://github.com/appium/WebDriverAgent/issues/658)) ([d7c397b](https://github.com/appium/WebDriverAgent/commit/d7c397b0260a71568edd6d99ecf7b39ca3503083))

## [4.10.21](https://github.com/appium/WebDriverAgent/compare/v4.10.20...v4.10.21) (2023-01-26)


### Bug Fixes

* Properly update maxDepth while fetching snapshots ([#655](https://github.com/appium/WebDriverAgent/issues/655)) ([6f99bab](https://github.com/appium/WebDriverAgent/commit/6f99bab5fbdbf65c9ef74c42b5f1b4c658aeaafb))

## [4.10.20](https://github.com/appium/WebDriverAgent/compare/v4.10.19...v4.10.20) (2023-01-17)


### Miscellaneous Chores

* **deps-dev:** bump semantic-release from 19.0.5 to 20.0.2 ([#651](https://github.com/appium/WebDriverAgent/issues/651)) ([e96c367](https://github.com/appium/WebDriverAgent/commit/e96c367cb0d9461bb5e443740504969a4cb857e1))

## [4.10.19](https://github.com/appium/WebDriverAgent/compare/v4.10.18...v4.10.19) (2023-01-13)


### Miscellaneous Chores

* **deps-dev:** bump appium-xcode from 4.0.5 to 5.0.0 ([#652](https://github.com/appium/WebDriverAgent/issues/652)) ([75c247f](https://github.com/appium/WebDriverAgent/commit/75c247fe82ebe7b2b8ba0d79528cadeda871e229))

## [4.10.18](https://github.com/appium/WebDriverAgent/compare/v4.10.17...v4.10.18) (2022-12-30)


### Miscellaneous Chores

* simplify Script/build-webdriveragent.js ([#647](https://github.com/appium/WebDriverAgent/issues/647)) ([81dab6c](https://github.com/appium/WebDriverAgent/commit/81dab6ca0645f9925a8515abfb4851d6e85da7e9))

## [4.10.17](https://github.com/appium/WebDriverAgent/compare/v4.10.16...v4.10.17) (2022-12-30)


### Miscellaneous Chores

* add  ARCHS=arm64 for a release package build ([#649](https://github.com/appium/WebDriverAgent/issues/649)) ([08612aa](https://github.com/appium/WebDriverAgent/commit/08612aade1833c384914bb618675b5653d5f5118))

## [4.10.16](https://github.com/appium/WebDriverAgent/compare/v4.10.15...v4.10.16) (2022-12-29)


### Miscellaneous Chores

* build only arm64 for generic build in a release ([#648](https://github.com/appium/WebDriverAgent/issues/648)) ([63e175d](https://github.com/appium/WebDriverAgent/commit/63e175d56526d9fb74d9053dbe60fd0c80b9c670))

## [4.10.15](https://github.com/appium/WebDriverAgent/compare/v4.10.14...v4.10.15) (2022-12-16)


### Miscellaneous Chores

* **deps:** bump @appium/base-driver from 8.7.3 to 9.0.0 ([#645](https://github.com/appium/WebDriverAgent/issues/645)) ([35dd981](https://github.com/appium/WebDriverAgent/commit/35dd98111f1d8222bc0cb412c11cb1442d10295e))
* **deps:** bump appium-ios-simulator from 4.2.1 to 5.0.1 ([#646](https://github.com/appium/WebDriverAgent/issues/646)) ([7911cbb](https://github.com/appium/WebDriverAgent/commit/7911cbb3607b1d75091bdf3dc436baae3868854a))

## [4.10.14](https://github.com/appium/WebDriverAgent/compare/v4.10.13...v4.10.14) (2022-12-14)


### Miscellaneous Chores

* **deps-dev:** bump @appium/test-support from 2.0.2 to 3.0.0 ([#644](https://github.com/appium/WebDriverAgent/issues/644)) ([ab84580](https://github.com/appium/WebDriverAgent/commit/ab8458027457563b7faaeef36d9019b7ac1921b0))
* **deps:** bump @appium/support from 2.61.1 to 3.0.0 ([#643](https://github.com/appium/WebDriverAgent/issues/643)) ([3ca197a](https://github.com/appium/WebDriverAgent/commit/3ca197ac7526036e408584207b26129847a615ca))

## [4.10.13](https://github.com/appium/WebDriverAgent/compare/v4.10.12...v4.10.13) (2022-12-13)

## [4.10.12](https://github.com/appium/WebDriverAgent/compare/v4.10.11...v4.10.12) (2022-12-08)


### Bug Fixes

* Provide proper xcodebuild argument for tvOS ([#640](https://github.com/appium/WebDriverAgent/issues/640)) ([72bd327](https://github.com/appium/WebDriverAgent/commit/72bd32780f26ae0f60b30e0cee8fc585aea600fe))

## [4.10.11](https://github.com/appium/WebDriverAgent/compare/v4.10.10...v4.10.11) (2022-11-29)

## [4.10.10](https://github.com/appium/WebDriverAgent/compare/v4.10.9...v4.10.10) (2022-11-25)


### Bug Fixes

* Only check existence if firstMatch is applied ([#638](https://github.com/appium/WebDriverAgent/issues/638)) ([5394fe8](https://github.com/appium/WebDriverAgent/commit/5394fe8cc2eda3d1668685bd00f9f7383e122627))

## [4.10.9](https://github.com/appium/WebDriverAgent/compare/v4.10.8...v4.10.9) (2022-11-25)

## [4.10.8](https://github.com/appium/WebDriverAgent/compare/v4.10.7...v4.10.8) (2022-11-24)

## [4.10.7](https://github.com/appium/WebDriverAgent/compare/v4.10.6...v4.10.7) (2022-11-24)

## [4.10.6](https://github.com/appium/WebDriverAgent/compare/v4.10.5...v4.10.6) (2022-11-23)

## [4.10.5](https://github.com/appium/WebDriverAgent/compare/v4.10.4...v4.10.5) (2022-11-22)

## [4.10.4](https://github.com/appium/WebDriverAgent/compare/v4.10.3...v4.10.4) (2022-11-22)

## [4.10.3](https://github.com/appium/WebDriverAgent/compare/v4.10.2...v4.10.3) (2022-11-22)

## [4.10.2](https://github.com/appium/WebDriverAgent/compare/v4.10.1...v4.10.2) (2022-11-06)

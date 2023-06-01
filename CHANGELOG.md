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

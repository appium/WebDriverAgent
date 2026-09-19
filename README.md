# WebDriverAgent

[![NPM version](http://img.shields.io/npm/v/appium-webdriveragent.svg)](https://npmjs.org/package/appium-webdriveragent)
[![Downloads](http://img.shields.io/npm/dm/appium-webdriveragent.svg)](https://npmjs.org/package/appium-webdriveragent)

[![Release](https://github.com/appium/WebDriverAgent/actions/workflows/publish.js.yml/badge.svg)](https://github.com/appium/WebDriverAgent/actions/workflows/publish.js.yml)

[![GitHub license](https://img.shields.io/badge/license-BSD-lightgrey.svg)](LICENSE)

WebDriverAgent is a [WebDriver server](https://w3c.github.io/webdriver/webdriver-spec.html) implementation for iOS that can be used to remote control iOS devices. It allows you to launch & kill applications, tap & scroll views or confirm view presence on a screen. This makes it a perfect tool for application end-to-end testing or general purpose device automation. It works by linking `XCTest.framework` and calling Apple's API to execute commands directly on a device. WebDriverAgent is developed for end-to-end testing and is successfully adopted by [Appium](http://appium.io) via [XCUITest driver](https://github.com/appium/appium-xcuitest-driver).

## Features
 * Both iOS and tvOS platforms are supported with devices & simulators
 * Implements most of [WebDriver Spec](https://w3c.github.io/webdriver/webdriver-spec.html)
 * Implements part of [Mobile JSON Wire Protocol Spec](https://github.com/SeleniumHQ/mobile-spec/blob/master/spec-draft.md)
 * USB support for devices is implemented via [appium-ios-device](https://github.com/appium/appium-ios-device) library and has zero dependencies on third-party tools.
 * Easy development cycle as it can be launched & debugged directly via Xcode
 * Use [Mac2Driver](https://github.com/appium/appium-mac2-driver) to automate macOS apps

## Getting Started On This Repository

You need to have Node.js installed for this project.

After it is finished you can simply open `WebDriverAgent.xcodeproj` and start `WebDriverAgentRunner` test
and start sending [requests](https://github.com/facebook/WebDriverAgent/wiki/Queries).

More about how to start WebDriverAgent [here](https://github.com/facebook/WebDriverAgent/wiki/Starting-WebDriverAgent).

## Reading Device Location on iOS

`GET /wda/device/location` reads location data without requesting permission.
If the runner has not requested permission before, it may not appear under
**Settings > Privacy & Security > Location Services**. To configure access:

1. Bring the **WebDriverAgent runner** to the foreground, for example with
   Appium's `mobile: activateApp` and the installed runner app's bundle identifier
   (including its `.xctrunner` suffix, where applicable).
2. Send the following request directly to WDA (replace the address with your WDA URL):

   ```sh
   curl -X POST http://localhost:8100/wda/device/location/authorization \
     -H 'Content-Type: application/json' -d '{"access":"whenInUse"}'
   ```

   Choose **Allow While Using App** on the device. **Allow Once** does not allow
   an immediate upgrade to Always authorization.
3. With the runner still in the foreground, request Always access:

   ```sh
   curl -X POST http://localhost:8100/wda/device/location/authorization \
     -H 'Content-Type: application/json' -d '{"access":"always"}'
   ```

   Choose **Change to Always Allow**. If iOS no longer offers a prompt, select
   **Always** for the runner in Location Services. Denied access must also be
   changed in Settings; restricted access may require changing device restrictions.
4. Return to the app under test and call `getGeoLocation` or WDA's
   `GET /wda/device/location`.

The authorization endpoint is iOS-only and accepts `access: "whenInUse"` or
`access: "always"`. It is also available at
`POST /session/:sessionID/wda/device/location/authorization`. It returns the
`authorizationStatus` observed before requesting permission; it does not wait
for the user to answer the prompt. Read `GET /wda/device/location` again after
answering. WDA does not activate itself or accept permission prompts automatically.
Requests that could display a prompt fail if the runner is not active.

Requesting `always` directly from an undetermined state can yield **provisional
Always** authorization, which also reports status `3`. The two-step flow above
provides an explicit upgrade from When In Use. See Apple's
[location authorization documentation](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestalwaysauthorization()).
Permissions may need configuring again after a privacy reset or runner identity
change. Even with authorization, location readings may initially be zero or
cached; this endpoint does not guarantee a fresh GPS fix after resetting a
simulated location.

## Known Issues
If you are having some issues please checkout [wiki](https://github.com/facebook/WebDriverAgent/wiki/Common-Issues) first.

## For Contributors
If you want to help us out, you are more than welcome to. However please make sure you have followed the guidelines in [CONTRIBUTING](CONTRIBUTING.md).

## Creating Bundles

`npm run bundle`

Then, you find `WebDriverAgentRunner-Runner-sim-<version>.zip`  for iOS and `WebDriverAgentRunner-Runner-tv_sim-<version>.zip` for tvOS files in the current directory.

## License

[`WebDriverAgent` is BSD-licensed](LICENSE).


Have fun!

# WebDriverAgent

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

## Known Issues
If you are having some issues please checkout [wiki](https://github.com/facebook/WebDriverAgent/wiki/Common-Issues) first.

## For Contributors
If you want to help us out, you are more than welcome to. However please make sure you have followed the guidelines in [CONTRIBUTING](CONTRIBUTING.md).

## Creating Bundles
Follow [this doc](docs/CREATING_BUNDLES.md)

## License

[`WebDriverAgent` is BSD-licensed](LICENSE). We also provide an additional [patent grant](PATENTS).

## Third Party Sources

WebDriverAgent depends on the following third-party frameworks:
- [CocoaHTTPServer](https://github.com/robbiehanson/CocoaHTTPServer)
- [RoutingHTTPServer](https://github.com/mattstevens/RoutingHTTPServer)

These projects haven't been maintained in a while. That's why the source code of these
projects has been integrated directly in the WebDriverAgent source tree.

You can find the source files and their licenses in the `WebDriverAgentLib/Vendor` directory.

Have fun!

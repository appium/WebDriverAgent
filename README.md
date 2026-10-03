# WebDriverAgent

[![NPM version](http://img.shields.io/npm/v/appium-webdriveragent.svg)](https://npmjs.org/package/appium-webdriveragent)
[![Downloads](http://img.shields.io/npm/dm/appium-webdriveragent.svg)](https://npmjs.org/package/appium-webdriveragent)

[![Release](https://github.com/appium/WebDriverAgent/actions/workflows/publish.js.yml/badge.svg)](https://github.com/appium/WebDriverAgent/actions/workflows/publish.js.yml)

[![GitHub license](https://img.shields.io/badge/license-BSD-lightgrey.svg)](LICENSE)

WebDriverAgent is a [WebDriver server](https://w3c.github.io/webdriver/webdriver-spec.html) implementation for iOS that can be used to remote control iOS devices. It allows you to launch & kill applications, tap & scroll views or confirm view presence on a screen. This makes it a perfect tool for application end-to-end testing or general purpose device automation. It works by linking `XCTest.framework` and calling Apple's API to execute commands directly on a device. WebDriverAgent is developed for end-to-end testing and is successfully adopted by [Appium](http://appium.io) via [XCUITest driver](https://github.com/appium/appium-xcuitest-driver).

## Features

- Both iOS and tvOS platforms are supported with devices & simulators
- Implements most of [WebDriver Spec](https://w3c.github.io/webdriver/webdriver-spec.html)
- Implements part of [Mobile JSON Wire Protocol Spec](https://github.com/SeleniumHQ/mobile-spec/blob/master/spec-draft.md)
- USB support for devices is implemented via [appium-ios-device](https://github.com/appium/appium-ios-device) library and has zero dependencies on third-party tools.
- Easy development cycle as it can be launched & debugged directly via Xcode
- Use [Mac2Driver](https://github.com/appium/appium-mac2-driver) to automate macOS apps

## Getting Started On This Repository

You need to have Node.js installed for this project.

After it is finished you can simply open `WebDriverAgent.xcodeproj` and start `WebDriverAgentRunner` test
and start sending [requests](https://github.com/facebook/WebDriverAgent/wiki/Queries).

More about how to start WebDriverAgent [here](https://github.com/facebook/WebDriverAgent/wiki/Starting-WebDriverAgent).

## Multiple displays

On devices such as iPhone Duo, `GET /wda/screens` lists the available displays.
Set `currentDisplayId` through `POST /session/:sessionId/appium/settings` to select
one of these IDs. Do not assume that the main display is the currently visible
one after folding or unfolding the device.

The setting selects the display for screenshots, MJPEG frames, and newly started
XCTest screen recordings. MJPEG follows setting changes on the existing
connection; an in-progress recording keeps the display selected when it started.
An unavailable display causes screenshots and recording requests to fail; MJPEG
pauses frame delivery until a valid display is selected. Set `currentDisplayId`
to `null` to restore the main display. WDA does not automatically switch this
setting when the device changes pose.

XCTest's active-app point lookup only targets the main display. When a secondary
display is selected, WDA uses its active-app fallback instead of that point lookup.
This is not display-specific app filtering: set `defaultActiveApplication` to the
app's bundle ID when multiple foreground apps make the result ambiguous. An app
specified when creating the session retains its existing priority.

W3C touch actions target the selected display. Viewport, element, and pointer
origins can be mixed within one action sequence; element offsets remain relative
to the element's center. Element scrolling uses the visible area in the same
coordinate space as the element frame, including on a rotated secondary display.

This gesture support builds on [#1269](https://github.com/appium/WebDriverAgent/pull/1269).

### Simulated hinge angle

On an iPhone Duo simulator, `POST /session/:sessionId/wda/device/hingeAngle` with
`{"angle": 90}` sends a hinge event without operating Device Hub's UI. The angle
must be a finite number from `0` (closed) to `180` (fully open); fractional values
are supported. This uses the simulator's private HID protocol verified with
Xcode 27.1 and is currently limited to model `iPhone19,4`. Other simulators and
physical devices return `unsupported operation`.

The response confirms event dispatch. Wait for the expected app layout before
continuing, since folding completes asynchronously. The command does not rotate
the device or update `currentDisplayId`; select the desired display separately.

## Known Issues

If you are having some issues please checkout [wiki](https://github.com/facebook/WebDriverAgent/wiki/Common-Issues) first.

## For Contributors

If you want to help us out, you are more than welcome to. However please make sure you have followed the guidelines in [CONTRIBUTING](CONTRIBUTING.md).

## Creating Bundles

`npm run bundle`

Then, you find `WebDriverAgentRunner-Runner-sim-<version>.zip` for iOS and `WebDriverAgentRunner-Runner-tv_sim-<version>.zip` for tvOS files in the current directory.

## License

[`WebDriverAgent` is BSD-licensed](LICENSE).

Have fun!

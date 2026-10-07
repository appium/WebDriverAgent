# Multiple displays

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

`GET /wda/screen` also follows `currentDisplayId`: `displayId` and `scale`
belong to the selected screen, and `screenSize` is its size in logical pixels,
adjusted to the active application's orientation. Unavailable selections return
an error. The status bar must belong to that display and be visible at its top.
Hidden containers and side-mounted status UI do not define a top-edge crop;
`statusBarSize` is zero when no such bar is present. Clients should refresh this
information after display, orientation, or status-bar changes.

The XCTest point lookup used by WDA has no display argument, including in the
Xcode 27.1 interfaces checked for this change. When a secondary display is
selected, WDA uses its active-app fallback instead of that main-display lookup.
This is not display-specific app filtering: set `defaultActiveApplication` to the
app's bundle ID when multiple foreground apps make the result ambiguous. An app
specified when creating the session retains its existing priority.

W3C touch actions target the selected display. Viewport, element, and pointer
origins can be mixed within one action sequence; element offsets remain relative
to the element's center. Element origins require `currentDisplayId` to match the
element's display; they do not override the selected display. Key-only and
pause-only sequences do not require the selected display to be available.
Element scrolling uses the visible area in the same
coordinate space as the element frame, including on rotated main and secondary displays.
WDA scrolling rejects an unavailable selected display instead of using an
uncorrected frame. Each normalized scroll keeps its converted frame and vector
in the same coordinate space across its drags. Keep the device orientation and
fold state stable until the command completes; change the display setting between
commands. Scroll-to-visible takes a fresh parent snapshot for each scroll step.

Native application-root coordinates on a secondary display require a containing
application window on that display. Requests outside those windows fail explicitly.

This gesture support builds on [#1269](https://github.com/appium/WebDriverAgent/pull/1269).

## Legacy SDK compatibility windows

Older-SDK apps can run in a compatibility window on iPhone Duo. Selecting the
correct `currentDisplayId` is still required, but it does not address failures
in XCTest's handling of that compatibility layout. This is separate from sending
a gesture to the wrong display.

A controlled comparison on the **iPhone Duo simulator, iOS 27.1 (24A94401)**
reproduced missed input without WDA. The same coordinate-probe app source was built
with **SDK 26.5 (Xcode 26.6)** and **SDK 27.2 (Xcode 27.2 beta 2)**, using separate
bundle IDs. Both were driven by the same Xcode 27.2 beta 2 UI-test runner. The
runner did not link WDA, and checked that WDA's `FBScreen` class was absent.
Only pose setup used simulated hinge injection; measured taps used public
`XCUIElement.tap()` and `coordinate(withNormalizedOffset:).tap()` APIs.

Each configuration tested the element center and four normalized positions.
The app recorded actual canvas-local touch coordinates and a touch counter;
returning from a tap without an XCTest error did not count as successful input.
Closed and fully open poses were repeated with the app order reversed, and the
second run also covered a 90-degree pose:

| Duo pose | SDK 26.5: touches received / attempted | SDK 27.2: touches received / attempted |
| --- | --- | --- |
| Closed (0 degrees) | 10 / 10 | 10 / 10 |
| Fully open (180 degrees) | 0 / 10 | 10 / 10 |
| Book (90 degrees) | 0 / 5 | 5 / 5 |

Successful taps differed from the expected canvas-local position by less than
0.17 points on either axis. The old-SDK app reported a 375 x 667 logical window
in both closed and open poses. On the inner display, XCTest reported the canvas
frame as approximately `(469, 6.67, 136.33, 111.67)`, while the app's own window
coordinates were `(20, 218, 335, 409)`. Different coordinate spaces can legitimately
have different frames; the evidence of failure is the missing delivered touches,
not the frame difference alone.

This isolates the observed failure to the Apple compatibility-display,
accessibility, or XCTest path rather than WDA's gesture-coordinate calculations.
It does not identify the failing internal Apple component. Results are limited
to this simulator/runtime, fixture, and SDK pair; physical Duo behavior and other
SDK combinations remain unverified. Rebuilding the fixture with SDK 27.2 avoided
the failure in this comparison, but is not a guarantee for every app.

WDA does not apply a speculative coordinate correction for compatibility windows.
When diagnosing a similar failure, first select the app's display explicitly,
then compare direct XCTest taps and app-recorded input before changing coordinate
transforms. For Apple's SDK-dependent layout guidance, see
[Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/).

## Validation and feedback

Duo display behavior has been tested on the iPhone Duo simulator with Xcode 27.1.
We have not had access to a physical Duo for testing. If you have access to one,
we would appreciate [reports of its display and capture behavior](https://github.com/appium/WebDriverAgent/issues),
including the device model, iOS/Xcode and WDA versions, selected display IDs,
requests and responses, and observed results.

# Multiple displays

On devices such as iPhone Duo, `GET /wda/screens` lists the available displays.
Set `currentDisplayId` through `POST /session/:sessionId/appium/settings` to select
one of these IDs. Do not assume that the main display is the currently visible
one after folding or unfolding the device.

The setting selects the display for screenshots and MJPEG frames, and passes the
selected display ID to newly started XCTest screen recordings (see the
[simulator recording limitation](#xctest-recording-on-the-duo-simulator) below). MJPEG follows setting changes on the existing
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
For an application-element origin on a secondary display, compute offsets from
its returned element rect, just as for any other element. XCTest may report that
rect with dimensions transposed relative to the application's window; WDA uses
the returned rect's center plus the requested offset as a viewport point and
applies the selected-display correction. Do not substitute the window's center
when calculating an offset for an application-element origin. This is separate
from the older-SDK compatibility issue below. Main-display application origins
retain their existing behavior.
Element scrolling uses the visible area in the same
coordinate space as the element frame, including on rotated main and secondary displays.
WDA scrolling rejects an unavailable selected display instead of using an
uncorrected frame. Each normalized scroll keeps its converted frame and vector
in the same coordinate space across its drags. Keep the device orientation and
fold state stable until the command completes; change the display setting between
commands. Scroll-to-visible takes a fresh parent snapshot for each scroll step.

Native application-root coordinates on a secondary display require a
non-empty application window on that display as a coordinate anchor. Edge and
outside coordinates are preserved, as on the main display; XCTest determines
how the gesture is delivered. No hit testing or clamping is performed here.
Requests fail if no such window exists on the selected display.

This gesture support builds on [#1269](https://github.com/appium/WebDriverAgent/pull/1269).

## Legacy SDK compatibility windows

“Legacy SDK” here means the SDK used to build the app: the tested older app was
built with **iOS SDK 26.5 (Xcode 26.6)** and ran in a compatibility window on
iPhone Duo. It does not refer to the device's iOS version or the SDK used to build
WDA. See Apple's [SDK-dependent layout guidance](https://developer.apple.com/videos/play/tech-talks/111461/).

On the **iPhone Duo simulator, iOS 27.1 (24A94401), with an Xcode 27.2 beta 2
UI-test runner**, direct XCTest element and coordinate taps failed to deliver
input to that app in fully open and some intermediate poses. The same app source
built with **SDK 27.2** received the taps. The failure reproduced without WDA;
it is a known limitation observed in the Apple compatibility-layout/XCTest path,
although the failing internal component has not been identified. Physical devices
and other SDK/runtime combinations remain unverified.

Select the app's `currentDisplayId` explicitly, but be aware that selecting the
correct display does not resolve this issue. WDA does not apply a compatibility
coordinate correction. Rebuilding with SDK 27.2 avoided the failure in the tested
app; for diagnosis, compare direct XCTest taps with app-recorded input.

## XCTest recording on the Duo simulator

On **iOS 27.1 (24A94401), with Xcode 27.2 beta 2**, the native XCTest
recording path produced black video for the closed Duo's outer display.
This reproduced after starting WDA afresh while the device was closed, as well
as after switching from the inner display back to the outer display.

The recorded native `XCTScreenRecordingRequest.screenID` was `1` for the outer
screen and `3` for the inner screen, matching the selected IDs returned by
`GET /wda/screens`. Simultaneous outer-display screenshots were correct at
1398 x 2034 pixels. Nevertheless, each four-second outer recording in the fresh
runner experiment contained only one black frame at 2006 x 2852 pixels; the
inner-display recording contained visible content. A successful start/stop
response is therefore insufficient to verify captured video.

The failure occurs downstream of the selected ID being supplied to XCTest;
this experiment does not identify the failing internal Apple component or
establish behavior on other runtimes or physical devices. WDA does not remap
display IDs to work around it. Use the MJPEG/ffmpeg recording path when affected;
that path was verified across closed, book, and fully open poses with both MJPEG
and H.264 output. Set `mjpegFixOrientation` to `true` if upright encoded MJPEG
pixels are required: the default preserves the existing EXIF-oriented output.

## Waiting for rotated layouts

An application's reported interface orientation can update before its element
frames settle. On an iPad simulator running iOS 26.5, the gesture fixture's Alerts
button briefly retained transposed dimensions immediately after rotation;
resolving an element-origin gesture during that interval missed the button.
The same failure reproduced on the unmodified WDA baseline. Waiting for the
fixture's expected landscape geometry resolved it; direct XCTest gesture
controls also passed. Tests should wait for the application's expected layout
before resolving coordinates, in addition to keeping its pose stable during a
command. This observation does not imply that every missed gesture is an
XCTest defect.

## Validation and feedback

Duo display behavior has been tested on the iPhone Duo simulator with Xcode 27.1
and Xcode 27.2 beta 2.
We have not had access to a physical Duo for testing. If you have access to one,
we would appreciate [reports of its display and capture behavior](https://github.com/appium/WebDriverAgent/issues),
including the device model, iOS/Xcode and WDA versions, selected display IDs,
requests and responses, and observed results.

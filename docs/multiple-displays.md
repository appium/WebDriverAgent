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

The XCTest point lookup used by WDA has no display argument, including in the
Xcode 27.1 interfaces checked for this change. When a secondary display is
selected, WDA uses its active-app fallback instead of that main-display lookup.
This is not display-specific app filtering: set `defaultActiveApplication` to the
app's bundle ID when multiple foreground apps make the result ambiguous. An app
specified when creating the session retains its existing priority.

W3C touch actions target the selected display. Viewport, element, and pointer
origins can be mixed within one action sequence; element offsets remain relative
to the element's center. Element scrolling uses the visible area in the same
coordinate space as the element frame, including on a rotated secondary display.
WDA scrolling rejects an unavailable selected display instead of using an
uncorrected frame. Each drag uses one converted scrolling frame; subsequent
drags refresh the display and orientation.

This gesture support builds on [#1269](https://github.com/appium/WebDriverAgent/pull/1269).

## Validation and feedback

Duo display behavior has been tested on the iPhone Duo simulator with Xcode 27.1.
We have not had access to a physical Duo for testing. If you have access to one,
we would appreciate [reports of its display and capture behavior](https://github.com/appium/WebDriverAgent/issues),
including the device model, iOS/Xcode and WDA versions, selected display IDs,
requests and responses, and observed results.

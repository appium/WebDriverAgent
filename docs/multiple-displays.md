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

This gesture support builds on [#1269](https://github.com/appium/WebDriverAgent/pull/1269).

## Simulated hinge angle

On an iPhone Duo simulator, `POST /session/:sessionId/wda/device/hingeAngle` with
`{"angle": 90}` sends a hinge event without operating Device Hub's UI. The angle
must be a finite number from `0` (closed) to `180` (fully open); fractional values
are supported. This uses a private HID protocol verified with Xcode 27.1 on the
iPhone Duo simulator. POST checks for a hinge and the required IOKit serialization,
event creation, and dispatch APIs. This permits an injection attempt; it does not
establish that the device accepts this vendor payload. Physical devices may attempt
injection when those prerequisites exist, but event acceptance and the resulting
angle/layout changes on a physical Duo remain unverified. Devices without these
prerequisites, tvOS, and watchOS return `unsupported operation`.

The response confirms event dispatch, not that the device applied the angle.
Wait for the expected app layout before continuing, since folding completes
asynchronously. The command does not rotate
the device or update `currentDisplayId`; select the desired display separately.

`GET /session/:sessionId/wda/device/hingeAngle` reads the current angle in degrees
and returns a numeric value, for example `{"value": 90.5}`. It reads CoreMotion
rather than remembering the last angle sent by WDA, so changes made outside WDA
are reflected too. The request waits up to five seconds for a valid reading and
returns an error if none arrives. GET separately checks for a hinge and the
CoreMotion subscription APIs; it does not depend on the IOKit injection APIs.
Devices without these reading prerequisites return `unsupported operation`.
A reading during a fold may reflect an intermediate angle; it does not wait for
the transition to finish.

Both hinge angle endpoints are also available without a session:
`GET /wda/device/hingeAngle` and `POST /wda/device/hingeAngle`. They operate on
the device and do not require creating an Appium session first.

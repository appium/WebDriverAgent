# mobilerun/pressAndDragWithVelocity

`POST /mobilerun/pressAndDragWithVelocity` performs press → drag → hold → lift through the
high-level `XCUICoordinate` gesture engine — the same engine as
`POST /session/{id}/wda/pressAndDragWithVelocity`. Unlike [`/mobilerun/actions`](mobilerun-actions.md),
whose raw synthesized HID events are not recognized as system gestures, gestures produced this
way trigger system behaviors such as the bottom-edge app-switcher swipe and the left-edge
swipe-back navigation gesture.

What makes it faster than the `/wda` endpoint:

1. Available session-less (`.withoutSession`), so no session needs to exist.
2. The app's quiescence waits — up to `waitForIdleTimeout` (default 10 s) before and after the
   gesture, the dominant latency of `/wda/pressAndDragWithVelocity` on a busy app — are
   suppressed for the duration of the call and restored afterwards.

Dispatch is synchronous: the call returns once the gesture has been played
(≈ `pressDuration` + distance/velocity + `holdDuration`).

## Query parameters

| param | notes |
|-------|-------|
| `scale` | optional positive number; same semantics as `/mobilerun/state` and `/mobilerun/actions`. Coordinates and velocity are logical points multiplied by this scale. Defaults to the native screen scale (device pixels, matching the screencapture stream). `scale=1` yields the `/wda` units: logical points and points per second. |

## Request body

A JSON object:

| field | type | required | notes |
|-------|------|----------|-------|
| `fromX`, `fromY` | number | yes | press location, in scaled units |
| `toX`, `toY` | number | yes | lift location, in scaled units |
| `velocity` | number | yes | drag speed in scaled units per second; must be > 0 |
| `pressDuration` | number | no (default 0) | seconds to hold at the start point before dragging |
| `holdDuration` | number | no (default 0) | seconds to hold at the end point before lifting |

The estimated total duration (`pressDuration` + distance/`velocity` + `holdDuration`) must not
exceed 60 s: the handler blocks the serialized route queue while the gesture plays, so an
unbounded gesture would stall every other endpoint.

## Examples

```bash
# drag a slider/cell: long-press 500 ms, drag down 400 px at 800 px/s, settle 250 ms
curl -X POST "$WDA/mobilerun/pressAndDragWithVelocity" -H 'Content-Type: application/json' \
  -d '{"fromX":200,"fromY":600,"toX":200,"toY":1000,"pressDuration":0.5,"velocity":800,"holdDuration":0.25}'

# left-edge swipe-back (system navigation gesture), logical points
curl -X POST "$WDA/mobilerun/pressAndDragWithVelocity?scale=1" -H 'Content-Type: application/json' \
  -d '{"fromX":2,"fromY":400,"toX":300,"toY":400,"pressDuration":0,"velocity":1200}'

# bottom-edge drag up + hold: open the app switcher
curl -X POST "$WDA/mobilerun/pressAndDragWithVelocity?scale=1" -H 'Content-Type: application/json' \
  -d '{"fromX":200,"fromY":850,"toX":200,"toY":450,"pressDuration":0,"velocity":600,"holdDuration":0.5}'
```

## Responses

- `200` `{"value": null}` — the gesture has been played.
- invalid argument — body is not a JSON object, a coordinate or `velocity` is missing or not a
  finite number, `velocity` ≤ 0, a duration is negative, `scale` is not positive, or the
  estimated duration exceeds 60 s.
- Failures raised by the gesture engine itself surface as regular WebDriver error responses
  through the standard exception handler.

## Which gesture endpoint to use

| endpoint | engine | system-gesture recognition | best for |
|----------|--------|---------------------------|----------|
| `/mobilerun/actions` | raw synthesized HID events | no | fastest taps/swipes/multi-touch inside apps |
| `/mobilerun/pressAndDragWithVelocity` | XCUICoordinate (quiescence suppressed) | yes | edge swipes, app switcher, long-press drag-and-drop, velocity semantics |
| `/session/{id}/wda/pressAndDragWithVelocity` | XCUICoordinate (full waits) | yes | when pre/post-gesture stability waits are desired |

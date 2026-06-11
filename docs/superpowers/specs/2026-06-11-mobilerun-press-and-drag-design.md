# Design: /mobilerun/pressAndDragWithVelocity

Date: 2026-06-11

## Problem

The droidrun platform performs press-and-drag gestures via
`POST /session/:id/wda/pressAndDragWithVelocity` (`FBElementCommands.m` →
`[XCUICoordinate pressForDuration:thenDragToCoordinate:withVelocity:thenHoldForDuration:]`).
Two latency sources are unrelated to the gesture itself:

1. The XCUITest gesture engine waits for app quiescence before/after the gesture
   (up to `FBConfiguration.waitForIdleTimeout`, default 10 s, on a busy app).
2. The route requires an active session.

The existing fast path, `/mobilerun/actions`, synthesizes raw HID event records.
Those are not reliably recognized as device/system gestures (observed on devices:
bottom-edge app-switcher swipe, left-edge swipe-back), so it cannot replace the
`XCUICoordinate` engine for this use case.

## Decision

Add `POST /mobilerun/pressAndDragWithVelocity` (with and without session) that calls the
**same** `XCUICoordinate` press-drag API — guaranteeing identical gesture recognition to
the `/wda` endpoint — while stripping the latency around it:

- registered `.withoutSession` like the rest of the `/mobilerun` namespace;
- the app's `fb_shouldWaitForQuiescence` flag is set to `NO` for the duration of the
  call and restored in `@finally` (the swizzle in `XCUIApplicationProcess+FBQuiescence`
  then short-circuits the pre/post idle waits); routes are serialized on the main
  queue, so the save/restore cannot race;
- app resolution follows the mobilerun pattern:
  `request.session.activeApplication ?: XCUIApplication.fb_activeApplication`.

Units follow the mobilerun scale convention: `fromX/fromY/toX/toY` and `velocity` are
logical points multiplied by the optional `scale` query parameter (default: native
screen scale = device pixels, matching `/mobilerun/state` and the screencapture
stream). `?scale=1` yields exact `/wda` semantics (logical points, points/sec).
Durations are seconds, like the `/wda` endpoint.

Validation is stricter than the `/wda` handler (which coerces missing args to 0):
coordinates and `velocity` are required finite numbers, `velocity > 0`, durations
≥ 0, and the estimated total duration (`pressDuration + distance/velocity +
holdDuration`; scale cancels) is capped at 60 s because the handler blocks the
serialized route queue while the gesture plays.

## Components

- `XCUIApplication+FBTouchAction.{h,m}` —
  `fb_mobilerunPressAndDragFromPoint:toPoint:pressDuration:velocity:holdDuration:`
  (coordinate construction, scoped quiescence suppression, gesture call).
- `FBMobilerunActionsCommands.m` — routes + `handlePressAndDragWithVelocity:`
  (body validation, scale conversion, duration cap, app resolution).
- Docs: `docs/mobilerun-press-and-drag.md`; cross-reference from
  `docs/mobilerun-actions.md`.
- Tests: `FBMobilerunActionsIntegrationTests.m` — zero-distance press-drag fires
  touch-up-inside (positive control), drag-away suppresses it (proves movement),
  quiescence flag restored.

## Alternatives rejected

- **Compose via `/mobilerun/actions` client-side:** zero server change, but raw HID
  records are not recognized for system gestures, which is the primary use case.
- **Logical-points-only payload (exact `/wda` body):** inconsistent with the other
  `/mobilerun` endpoints; `?scale=1` provides the same semantics on demand.

## Verification (performed on iPhone 17 Pro simulator, iOS 26.4)

- Integration tests green (3 new + 4 pre-existing in the class).
- Live: left-edge swipe-back navigates back in Settings via the new endpoint;
  in-app drags scroll correctly with both `scale=1` and default device-pixel units;
  all eight validation rejection paths return `invalid argument`.
- Latency for an identical 0.8 s gesture on an idle app: `/wda` 1.7–2.1 s vs
  `/mobilerun` 1.22 s (consistent across rounds); on busy apps the suppression
  additionally avoids up-to-10 s idle stalls.
- Simulator caveat: the app-switcher gesture triggers via neither engine on the
  simulator, and the in-app edge-swipe happens to be recognized for raw HID events
  there too — the recognition gap motivating this endpoint was observed on real
  devices. Recognition parity with `/wda` holds by construction (same API call).

# Design: `POST /mobilerun/actions` — fast-path pointer gestures

**Date:** 2026-06-10
**Branch:** `timo/dro-2199-wda-fast-input-a11y`
**Status:** Approved

## Goal

Add a low-latency input endpoint under the `/mobilerun` namespace that performs
pointer gestures (tap, long-press, swipe, multi-touch) by synthesizing HID events
directly, bypassing the W3C `POST /actions` machinery. The W3C path is correct but
carries avoidable per-call cost; this endpoint cuts everything that isn't required
to put the event on the wire.

## Motivation — what the W3C path costs

`POST /actions` (`FBTouchActionCommands` → `XCUIApplication+FBTouchAction
fb_performW3CActions:` → `FBW3CActionsSynthesizer`) does the following per request:

1. Parses the nested W3C envelope `{actions:[{type:"pointer", parameters, actions:[…]}]}`,
   allocating a gesture-item object per action item with validation passes.
2. Runs `preprocessedActionItemsWith:` (reverse enumeration, pointer-cancel handling,
   element-cache origin resolution + staleness checks).
3. Synthesizes `XCPointerEventPath`s, wraps them in an `XCSynthesizedEventRecord`,
   dispatches via `FBXCTestDaemonsProxy synthesizeEventWithRecord:`.
4. **After dispatch, runs `fb_waitUntilStableWithTimeout:` (animation cool-off).**

Steps 1–2 and step 4 are overhead for a caller that already knows the exact screen
coordinates and does not need element resolution or a settle barrier. Step 4 (the
stability wait) is typically the largest wall-clock cost.

## Endpoint

| | |
|---|---|
| Method | `POST` |
| Path | `/mobilerun/actions` |
| Routes | with-session **and** `.withoutSession` (mirrors `/mobilerun/state`) |
| Handler | new class `FBMobilerunActionsCommands` (auto-registered via `FBCommandHandler` conformance) |

## Request body

A **top-level JSON array** of flat pointer-event items. WDA parses the body with
`NSJSONSerialization JSONObjectWithData:` (`FBWebServer.m`), which returns an
`NSArray` for a top-level array; it flows into `request.arguments` unchanged (the
declared `NSDictionary *` type is not enforced at runtime). The handler validates
`[request.arguments isKindOfClass:NSArray.class]`.

Item schema (the client's `TapAction`, plus one optional field):

```go
type TapAction struct {
    Type      string `json:"type"`      // pointerDown | pointerMove | pointerUp | pause
    Duration  int    `json:"duration"`  // milliseconds
    X         int    `json:"x"`
    Y         int    `json:"y"`
    Button    int    `json:"button"`    // accepted; ignored for touch
    PointerId int    `json:"pointerId"` // optional; omit/0 = single finger
}
```

Examples:

```json
// tap at (100, 200)
[
  {"type":"pointerDown","x":100,"y":200},
  {"type":"pointerUp","x":100,"y":200}
]

// 150 ms swipe up from (100, 600) to (100, 200)
[
  {"type":"pointerDown","x":100,"y":600},
  {"type":"pointerMove","x":100,"y":200,"duration":150},
  {"type":"pointerUp","x":100,"y":200}
]

// two-finger pinch-in: both fingers move toward center over 200 ms
[
  {"type":"pointerDown","x":100,"y":400,"pointerId":0},
  {"type":"pointerMove","x":190,"y":400,"duration":200,"pointerId":0},
  {"type":"pointerUp","x":190,"y":400,"pointerId":0},
  {"type":"pointerDown","x":300,"y":400,"pointerId":1},
  {"type":"pointerMove","x":210,"y":400,"duration":200,"pointerId":1},
  {"type":"pointerUp","x":210,"y":400,"pointerId":1}
]
```

## Semantics

A single request builds one `XCSynthesizedEventRecord` containing one
`XCPointerEventPath` **per distinct `pointerId`**. Items are processed in array
order; each item is applied to the path for its `pointerId`.

Per-item effect (offsets in milliseconds, converted with `FBMillisToSeconds`):

| `type` | effect on that pointer's path |
|---|---|
| `pointerDown` | if path not yet created: `initForTouchAtPoint:(x,y) offset:offset` (positions **and** presses); else `pressDownAtOffset:offset` (re-press for double-tap) |
| `pointerMove` | if path not yet created (leading move): `initForTouchAtPoint:(x,y) offset:offset+duration`; else `moveToPoint:(x,y) atOffset:offset+duration` |
| `pointerUp` | `liftUpAtOffset:offset` (error if the path has no prior down) |
| `pause` | no event emitted |

After each item, that pointer's running offset advances by `duration`.

Because `pressDownAtOffset:` carries no coordinate, a re-press (`pointerDown` on a path
that already exists) presses at the pointer's current location — correct for a
same-spot double-tap. To press again at a **different** location on the same finger,
the client inserts a `pointerMove` to that location first. The common gestures (tap,
long-press, swipe) and multi-touch never hit the re-press path.

**Timing model.** Each `pointerId` keeps its **own** running offset, accumulating only
its own items' durations. All paths share the event record's clock, so two fingers
whose first `pointerDown` are both at offset 0 press simultaneously. To synchronize a
multi-finger move (e.g. pinch), the client gives the concurrent moves matching
`duration`s. Interleaving of different pointers within the array does not affect
timing — only each pointer's own duration sequence does. This is the flat-array
equivalent of W3C "ticks" without the envelope.

This mirrors the W3C synthesizer's offset arithmetic exactly (`pointerDown` at
`offset`, `pointerMove` at `offset+duration`, `pointerUp` at `offset`), so a gesture
expressed here lands identically to the same gesture via `/actions`.

`button` is accepted for wire parity but ignored (touch pointer = button 0).
`pointerId` defaults to `0` when omitted, so a body that never sets it is a single
finger — the original tap/swipe case.

## Dispatch & latency

`XCUIApplication+FBTouchAction` gains:

```objc
- (BOOL)fb_performMobilerunActions:(NSArray *)items error:(NSError **)error;
```

It builds the per-pointer paths, wraps them in
`XCSynthesizedEventRecord initWithName:@"Mobilerun Action" interfaceOrientation:self.interfaceOrientation`,
and dispatches via the existing `fb_synthesizeEvent:error:`
(`FBXCTestDaemonsProxy synthesizeEventWithRecord:`).

**Cut vs `/actions`:** no W3C envelope parsing, no `preprocessedActionItemsWith:`,
no element-cache resolution, and **no `fb_waitUntilStableWithTimeout:`** afterward.

**Dispatch stays synchronous.** `synthesizeEventWithRecord:` spin-waits only until the
daemon finishes *playing* the event — instantaneous for a tap, equal to the requested
`duration` for a swipe/long-press (inherent, not overhead). Keeping it synchronous
preserves error reporting and prevents rapid back-to-back requests from racing
mid-play. A fire-and-forget mode is intentionally **out of scope** for v1; it could be
added later as an opt-in flag if profiling shows the spin-wait dominates.

The app is resolved as `request.session.activeApplication ?: XCUIApplication.fb_activeApplication`
— the session's cached app (cheap) when a session exists, falling back for the
sessionless route. The active app supplies `interfaceOrientation`, matching the W3C
path's coordinate interpretation.

## Components

- **`FBMobilerunActionsCommands` (`.h`/`.m`, new)** — thin command handler. Declares the
  two routes; the handler resolves the app, validates the array, calls
  `fb_performMobilerunActions:error:`, and returns `FBResponseWithOK()` /
  `FBResponseWithUnknownError(error)` / an invalid-argument response.
- **`XCUIApplication+FBTouchAction` (extended)** — `fb_performMobilerunActions:error:`
  owns parsing the flat items into per-pointer `XCPointerEventPath`s and dispatching.
  Lives beside its W3C cousin and reuses `fb_synthesizeEvent:error:`.

## Error handling

Invalid-argument response (no event dispatched) when:
- body is not an array, or is empty;
- an item is not an object, or `type` is missing/unsupported;
- `pointerDown`/`pointerMove` is missing `x` or `y`;
- a `pointerId` group's `pointerUp` has no preceding down (path not created).

Synthesis failure from the daemon → `FBResponseWithUnknownError(error)`.

## Testing

Integration test mirroring `FBW3CTouchActionsIntegrationTests` (requires the test-host
simulator): drive a tap and a swipe through `fb_performMobilerunActions:` and assert the
UI reacts (e.g. a button fires, a scroll view moves), plus a two-finger case asserting
both paths are added to the record. Unit-level validation tests for the error cases that
don't need a live device where practical.

## Project wiring

Add `FBMobilerunActionsCommands.h`/`.m` to `WebDriverAgent.xcodeproj/project.pbxproj`,
mirroring every insertion point used by `FBMobilerunA11yCommands` (PBXBuildFile entries,
PBXFileReference, the group children, and the Sources/Headers build phases) across both
targets.

## Documentation

Add `docs/mobilerun-actions.md` as an API reference, matching the style of
`docs/mobilerun-screencapture.md` (endpoint, body schema, examples, semantics, and the
explicit "what it skips vs `/actions`" note).

## Out of scope (YAGNI)

- Fire-and-forget / async dispatch (noted above as a possible future opt-in).
- Key/text actions (`type:"key"`) — this endpoint is pointer-only.
- Element-relative origins — callers send absolute screen coordinates.
- Pressure / force-touch.

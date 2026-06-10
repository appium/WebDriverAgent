# mobilerun/actions

`POST /mobilerun/actions` performs pointer gestures (tap, long-press, swipe,
multi-touch) by synthesizing HID events directly. It is a low-latency alternative to
the W3C `POST /session/{id}/actions`: it skips the W3C envelope parsing, element-cache
resolution, and the post-gesture animation-stability wait.

Available both with a session and session-less (`.withoutSession`).

## Request body

A top-level JSON array of flat action items, replayed in array order:

| field | type | notes |
|-------|------|-------|
| `type` | string | `pointerDown` \| `pointerMove` \| `pointerUp` \| `pause` |
| `x`, `y` | int | screen coordinates; required for `pointerDown`/`pointerMove` |
| `duration` | int | milliseconds; move time for `pointerMove`, wait for `pause` |
| `button` | int | accepted for parity; ignored (touch) |
| `pointerId` | int | optional, default 0; items sharing an id form one finger; distinct ids run concurrently |

## Semantics

Each `pointerId` builds one touch path with its own running offset (accumulating only
its own items' `duration`). Paths play on a shared clock, so two fingers whose first
`pointerDown` are both at offset 0 press simultaneously; synchronize a pinch by giving
the concurrent moves matching `duration`s. `pointerDown` happens at `offset`,
`pointerMove` completes at `offset + duration`, and `pointerUp` at `offset` — identical
timing to the W3C path. A re-`pointerDown` on an existing path presses at the pointer's
current location (same-spot double-tap); insert a `pointerMove` first to re-press
elsewhere.

## Examples

```bash
# tap at (100, 200)
curl -X POST "$WDA/mobilerun/actions" -H 'Content-Type: application/json' \
  -d '[{"type":"pointerDown","x":100,"y":200},{"type":"pointerUp","x":100,"y":200}]'

# 150 ms swipe up from (100, 600) to (100, 200)
curl -X POST "$WDA/mobilerun/actions" -H 'Content-Type: application/json' \
  -d '[{"type":"pointerDown","x":100,"y":600},
       {"type":"pointerMove","x":100,"y":200,"duration":150},
       {"type":"pointerUp","x":100,"y":200}]'

# two-finger pinch-in (both fingers move toward centre over 200 ms)
curl -X POST "$WDA/mobilerun/actions" -H 'Content-Type: application/json' \
  -d '[{"type":"pointerDown","x":100,"y":400,"pointerId":0},
       {"type":"pointerMove","x":190,"y":400,"duration":200,"pointerId":0},
       {"type":"pointerUp","x":190,"y":400,"pointerId":0},
       {"type":"pointerDown","x":300,"y":400,"pointerId":1},
       {"type":"pointerMove","x":210,"y":400,"duration":200,"pointerId":1},
       {"type":"pointerUp","x":210,"y":400,"pointerId":1}]'
```

## Responses

- `200` `{"value": null}` — dispatched.
- invalid argument — body is not a JSON array, an item has no/unknown `type`, a
  `pointerDown`/`pointerMove` lacks `x`/`y`, or a `pointerUp` has no preceding down.
- unknown error — the event synthesizer rejected the record.

## What it skips vs `/session/{id}/actions`

1. No W3C envelope (`{actions:[{type:"pointer",parameters,actions:[…]}]}`) parsing.
2. No element-cache origin resolution.
3. No `fb_waitUntilStableWithTimeout` after dispatch — the caller decides when to wait.

Dispatch is synchronous: the call returns once the daemon finishes playing the gesture
(instant for a tap, equal to `duration` for a swipe/long-press).

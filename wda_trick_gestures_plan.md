# Custom WDA Endpoint: `POST /wda/perform_trick_gestures`

## Why

Appium's W3C Actions layer cannot deliver two sequential gestures with precisely zero gap between them:

- **Single-packet W3C Actions** (one `perform()` call): Any pointer movement between `pointerUp` and the next `pointerDown` — even a "hover" — generates visible touch events in True Skate. WDA also rejects a bare `pause` not preceded by a `pointerMove`, forcing this phantom trace.
- **Two HTTP requests**: Irreducible round-trip latency between the two calls means `delay=0` always incurs a gap (~50–150ms).

The root cause is that both problems are in WDA's W3C Actions *translation layer* — not in the underlying XCTest event APIs. WDA internally uses `XCSynthesizedEventRecord` + `XCPointerEventPath` to schedule touch events with arbitrary absolute time offsets. A custom endpoint that talks to those APIs directly can schedule both gestures in one atomic event record, with zero movement between them and device-native timing precision.

---

## How It Works

`XCSynthesizedEventRecord` holds one or more `XCPointerEventPath` objects. Each path is an independent touch contact with events at absolute time offsets (in seconds from t=0). When played, all paths execute simultaneously on the device — WDA's internal scheduler fires each event at its specified time with no network round-trips.

For sequential gestures with a delay:
- **Path 0**: `pressDown` at `t=0`, moves through g0, `liftUp` at `t=g0_duration`
- **Path 1**: `pressDown` at `t=g0_duration + delay`, moves through g1, `liftUp` at `t=g0_duration + delay + g1_duration`

Between `liftUp` and the next `pressDown` there are **no events** — not even a hover. True Skate sees nothing in the gap.

For `delay=0`: path 1's `pressDown` is at exactly `t=g0_duration`. Gapless.
For `delay<0` (overlap): path 1's `pressDown` is before path 0's `liftUp`. Both contacts are active simultaneously.

---

## WDA Implementation

### Git Setup

```bash
# Fork appium/WebDriverAgent on GitHub first, then:
rm -rf ~/Projects/WebDriverAgent
git clone https://github.com/AsherNoble/WebDriverAgent.git ~/Projects/WebDriverAgent
git -C ~/Projects/WebDriverAgent remote add upstream https://github.com/appium/WebDriverAgent.git
git -C ~/Projects/WebDriverAgent checkout -b feature/trueskate-trick-gestures
```

### Auto-Discovery

WDA discovers command handlers automatically via `FBClassesThatConformsToProtocol(@protocol(FBCommandHandler))` in `FBWebServer.m`. Any class conforming to `FBCommandHandler` that is included in the Xcode target is registered — no changes to `FBWebServer.m` needed.

### New Files

**`WebDriverAgentLib/Commands/FBTrickGestureCommands.h`**

```objc
#import <Foundation/Foundation.h>
#import "FBCommandHandler.h"

NS_ASSUME_NONNULL_BEGIN

@interface FBTrickGestureCommands : NSObject <FBCommandHandler>
@end

NS_ASSUME_NONNULL_END
```

**`WebDriverAgentLib/Commands/FBTrickGestureCommands.m`**

```objc
#import "FBTrickGestureCommands.h"

#import <UIKit/UIKit.h>
#import "FBResponsePayload.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBSession.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCPointerEventPath.h"
#import "XCSynthesizedEventRecord.h"

@implementation FBTrickGestureCommands

+ (NSArray *)routes
{
  return @[
    [[FBRoute POST:@"/wda/perform_trick_gestures"] respondWithTarget:self action:@selector(handlePerformTrickGestures:)],
  ];
}

/**
 * Executes multiple sequential (or overlapping) touch gestures as a single
 * XCSynthesizedEventRecord, achieving device-native inter-gesture timing
 * with zero phantom touches between gestures.
 *
 * Request body:
 * {
 *   "gestures": [
 *     {
 *       "waypoints": [
 *         {"x": 207, "y": 486, "duration_ms": 0},    // first point, duration_ms ignored
 *         {"x": 207, "y": 552, "duration_ms": 13},   // move here over 13ms
 *         {"x": 207, "y": 618, "duration_ms": 36}    // move here over 36ms
 *       ]
 *     },
 *     {
 *       "waypoints": [...]
 *     }
 *   ],
 *   "delay_ms": 0    // gap between end of gesture[n] and start of gesture[n+1]
 * }
 *
 * delay_ms=0  → gesture[1] starts exactly when gesture[0] ends.
 * delay_ms>0  → gap between end and start.
 * delay_ms<0  → overlap (gesture[1] starts before gesture[0] ends).
 *
 * Validation: (g0_duration + delay_ms) must be >= 0, otherwise gesture[1]
 * would start before gesture[0] begins.
 */
+ (id<FBResponsePayload>)handlePerformTrickGestures:(FBRouteRequest *)request
{
  NSArray *gestures = request.arguments[@"gestures"];
  if (![gestures isKindOfClass:NSArray.class] || gestures.count == 0) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:
      @"'gestures' must be a non-empty array" traceback:nil]);
  }

  double delayS = [request.arguments[@"delay_ms"] doubleValue] / 1000.0;

  UIInterfaceOrientation orientation = request.session.activeApplication.interfaceOrientation;
  XCSynthesizedEventRecord *record = [[XCSynthesizedEventRecord alloc]
    initWithName:@"TrickGesture"
    interfaceOrientation:orientation];

  // t_start: absolute time (seconds from t=0) at which the current gesture begins.
  double t_start = 0.0;

  for (NSUInteger gi = 0; gi < gestures.count; gi++) {
    NSDictionary *gesture = gestures[gi];
    NSArray *waypoints = gesture[@"waypoints"];

    if (![waypoints isKindOfClass:NSArray.class] || waypoints.count < 2) {
      return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:
        [NSString stringWithFormat:@"Gesture %lu must have at least 2 waypoints", (unsigned long)gi]
        traceback:nil]);
    }

    // First waypoint: touch contact origin.
    NSDictionary *first = waypoints[0];
    CGPoint origin = CGPointMake([first[@"x"] doubleValue], [first[@"y"] doubleValue]);

    XCPointerEventPath *path = [[XCPointerEventPath alloc] initForTouchAtPoint:origin
                                                                         offset:t_start];
    [path pressDownAtOffset:t_start];

    // Subsequent waypoints: accumulate time.
    double t_cursor = t_start;
    for (NSUInteger wi = 1; wi < waypoints.count; wi++) {
      NSDictionary *wp = waypoints[wi];
      t_cursor += [wp[@"duration_ms"] doubleValue] / 1000.0;
      CGPoint pt = CGPointMake([wp[@"x"] doubleValue], [wp[@"y"] doubleValue]);
      [path moveToPoint:pt atOffset:t_cursor];
    }

    [path liftUpAtOffset:t_cursor];
    [record addPointerEventPath:path];

    // Next gesture starts at: end of this gesture + delay.
    t_start = t_cursor + delayS;

    // Validate: next gesture cannot start before t=0.
    if (gi < gestures.count - 1 && t_start < 0.0) {
      return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:
        [NSString stringWithFormat:
          @"delay_ms=%.0f causes gesture %lu to start before t=0",
          delayS * 1000.0, (unsigned long)(gi + 1)]
        traceback:nil]);
    }
  }

  NSError *error;
  if (![FBXCTestDaemonsProxy synthesizeEventWithRecord:record error:&error]) {
    return FBResponseWithUnknownError(error);
  }

  return FBResponseWithOK();
}

@end
```

### Add to Xcode Target

In Xcode, drag both files into `WebDriverAgentLib/Commands/`. Make sure **Target Membership** is checked for `WebDriverAgentLib`.

### Build & Deploy

```bash
cd ~/Projects/WebDriverAgent
xcodebuild -project WebDriverAgent.xcodeproj \
  -scheme WebDriverAgentRunner \
  -destination 'id=<DEVICE_UDID>' \
  -allowProvisioningUpdates \
  test
```

Or build from Xcode directly (Product → Test on the device).

---

## Python Integration

### Request Format

The Python side pre-computes per-segment durations (already done by `_easing_to_segment_durations`) and sends them as a list of waypoints with `duration_ms`.

### Changes to `execute_trick.py`

Replace `_execute_two_gestures` with a direct POST to `/wda/perform_trick_gestures`. Note: go to the **WDA port directly** (8101 for iPhone 11) to avoid Appium's W3C validation layer, which may reject or transform the custom route.

```python
def _wda_waypoints(points, total_duration, easing):
    """Build waypoint dicts from gesture points + easing for the WDA endpoint."""
    n_segments = len(points) - 1
    total_ms = int(total_duration * 1000)
    if easing is None:
        durations = [max(1, total_ms // n_segments)] * n_segments
    else:
        durations = _easing_to_segment_durations(n_segments, total_ms, easing)
    x0, y0 = points[0]
    waypoints = [{"x": round(x0), "y": round(y0), "duration_ms": 0}]
    for (x, y), dur in zip(points[1:], durations):
        waypoints.append({"x": round(x), "y": round(y), "duration_ms": dur})
    return waypoints


def _execute_two_gestures(driver, g0_points, g1_points, g0_duration, g1_duration,
                          delay, easing0, easing1, wda_url):
    payload = {
        "gestures": [
            {"waypoints": _wda_waypoints(g0_points, g0_duration, easing0)},
            {"waypoints": _wda_waypoints(g1_points, g1_duration, easing1)},
        ],
        "delay_ms": int(delay * 1000),
    }
    url = f"{wda_url.rstrip('/')}/session/{driver.session_id}/wda/perform_trick_gestures"
    resp = requests.post(url, json=payload, timeout=15)
    resp.raise_for_status()
```

Update `execute_recipe` to accept `wda_url` instead of `appium_url`, and pass `f"http://127.0.0.1:{worker._cfg['wda_port']}"` from `main()`.

---

## Testing Checklist

1. `delay_ms=1000` (kickflip): visible 1-second gap, no phantom trace between gestures.
2. `delay_ms=0`: genuinely gapless — no perceptible gap, no phantom trace.
3. `delay_ms=-50` (overlap): both gestures active simultaneously.
4. Invalid: `delay_ms < -g0_duration_ms` → WDA returns error, Python raises.
5. Landing rate: compare kickflip landing rate vs. the previous sequential approach.

---

## Risks

- `XCSynthesizedEventRecord` and `XCPointerEventPath` are private XCTest APIs. Stable across iOS versions in practice (WDA depends on them), but could break with a major Xcode/iOS update.
- The offset semantics (`initForTouchAtPoint:offset:` and subsequent event offsets) should be verified against `FBW3CActionsSynthesizer.m` during implementation — specifically, whether offsets are relative to path creation time or absolute from record start. The plan above assumes **absolute**.

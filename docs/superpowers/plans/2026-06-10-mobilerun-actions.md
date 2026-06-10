# Mobilerun Fast-Path Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `POST /mobilerun/actions`, a low-latency pointer-gesture endpoint that synthesizes HID events directly from a flat action array, bypassing the W3C envelope, element cache, and post-gesture stability wait.

**Architecture:** A new category method `XCUIApplication+FBTouchAction fb_performMobilerunActions:error:` parses a flat array of `{type,x,y,duration,button,pointerId}` items into one `XCPointerEventPath` per `pointerId`, wraps them in a single `XCSynthesizedEventRecord`, and dispatches via the existing `fb_synthesizeEvent:error:` (`FBXCTestDaemonsProxy`). A thin `FBMobilerunActionsCommands` handler exposes it over HTTP and auto-registers through `FBCommandHandler` conformance.

**Tech Stack:** Objective-C, WebDriverAgent routing (`FBRoute`/`FBRouteRequest`/`FBResponsePayload`), private XCTest event-synthesis headers (`XCPointerEventPath`, `XCSynthesizedEventRecord`), Xcode project (`project.pbxproj`).

**Reference spec:** `docs/superpowers/specs/2026-06-10-mobilerun-actions-design.md`

---

## File Structure

- **Modify** `WebDriverAgentLib/Categories/XCUIApplication+FBTouchAction.h` — declare `fb_performMobilerunActions:error:`.
- **Modify** `WebDriverAgentLib/Categories/XCUIApplication+FBTouchAction.m` — implement it + a private point-parsing helper; add imports.
- **Create** `WebDriverAgentLib/Commands/FBMobilerunActionsCommands.h` / `.m` — the HTTP handler.
- **Modify** `WebDriverAgent.xcodeproj/project.pbxproj` — wire the new command files into both library targets, and the new test file into the test target.
- **Create** `WebDriverAgentTests/IntegrationTests/FBMobilerunActionsIntegrationTests.m` — behavioral test driving the category method.
- **Create** `docs/mobilerun-actions.md` — API reference.

## Build / test commands

There is no Makefile. Commands (a booted simulator + Xcode are required for the test run):

- Compile the library: `xcodebuild build -project WebDriverAgent.xcodeproj -scheme WebDriverAgentLib -destination 'generic/platform=iOS Simulator' -quiet`
- Build the tests (compile-only inner loop): `xcodebuild build-for-testing -project WebDriverAgent.xcodeproj -scheme IntegrationTests_1 -destination 'platform=iOS Simulator,name=iPhone 15'`
- Run the new test: `xcodebuild test -project WebDriverAgent.xcodeproj -scheme IntegrationTests_1 -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:WebDriverAgentTests/FBMobilerunActionsIntegrationTests`

> If `IntegrationTests_1` does not include the new file's target membership, use the scheme whose Test action lists `WebDriverAgentTests` (the same target `FBW3CTouchActionsIntegrationTests.m` belongs to). Confirm with `grep -n "FBW3CTouchActionsIntegrationTests" WebDriverAgent.xcodeproj/project.pbxproj`.

---

## Task 1: Behavioral test for the fast path (test-first)

**Files:**
- Create: `WebDriverAgentTests/IntegrationTests/FBMobilerunActionsIntegrationTests.m`
- Modify: `WebDriverAgent.xcodeproj/project.pbxproj` (test target wiring)

The test mirrors `FBW3CTouchActionsIntegrationTests` but calls the new `fb_performMobilerunActions:`. It taps the alert-trigger button on the Alerts page and asserts an alert appears — proving the synthesized gesture lands like the W3C path.

- [ ] **Step 1: Write the failing test**

Create `WebDriverAgentTests/IntegrationTests/FBMobilerunActionsIntegrationTests.m`:

```objc
/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <XCTest/XCTest.h>

#import "FBIntegrationTestCase.h"
#import "FBTestMacros.h"
#import "XCUIApplication+FBTouchAction.h"
#import "XCUIElement.h"

@interface FBMobilerunActionsIntegrationTests : FBIntegrationTestCase
@end

@implementation FBMobilerunActionsIntegrationTests

- (void)setUp
{
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self launchApplication];
    [self goToAlertsPage];
  });
  [self clearAlert];
}

- (void)tearDown
{
  [self clearAlert];
  [super tearDown];
}

- (CGPoint)alertButtonCenter
{
  XCUIElement *button = self.testedApplication.buttons[@"Create App Alert"];
  CGRect frame = button.frame;
  return CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
}

- (void)testTapShowsAlert
{
  CGPoint p = [self alertButtonCenter];
  NSArray *actions = @[
    @{@"type": @"pointerDown", @"x": @(p.x), @"y": @(p.y)},
    @{@"type": @"pointerUp", @"x": @(p.x), @"y": @(p.y)},
  ];
  NSError *error;
  XCTAssertTrue([self.testedApplication fb_performMobilerunActions:actions error:&error]);
  XCTAssertNil(error);
  FBAssertWaitTillBecomesTrue(self.testedApplication.alerts.count > 0);
}

- (void)testRejectsNonArrayAndEmpty
{
  NSError *error;
  XCTAssertFalse([self.testedApplication fb_performMobilerunActions:@[] error:&error]);
  XCTAssertNotNil(error);

  error = nil;
  XCTAssertFalse([self.testedApplication fb_performMobilerunActions:(NSArray *)@{@"type": @"pointerDown"} error:&error]);
  XCTAssertNotNil(error);
}

- (void)testRejectsPointerUpWithoutDown
{
  NSError *error;
  NSArray *actions = @[@{@"type": @"pointerUp", @"x": @100, @"y": @100}];
  XCTAssertFalse([self.testedApplication fb_performMobilerunActions:actions error:&error]);
  XCTAssertNotNil(error);
}

@end
```

> The Alerts page button label is `Create App Alert` in the IntegrationApp. If the integration host uses a different label, confirm with `grep -rn "App Alert" IntegrationApp` and adjust the accessibility id.

- [ ] **Step 2: Wire the test file into the test target in `project.pbxproj`**

Mirror the four `FBW3CTouchActionsIntegrationTests.m` entries (find them with `grep -n "FBW3CTouchActionsIntegrationTests" WebDriverAgent.xcodeproj/project.pbxproj`). Add a sibling line directly after each, using new UUIDs `FBCAFE000000000000003201` (fileRef) and `FBCAFE000000000000003202` (build file):

In the `PBXBuildFile` section (after line containing `FBW3CTouchActionsIntegrationTests.m in Sources`):
```
		FBCAFE000000000000003202 /* FBMobilerunActionsIntegrationTests.m in Sources */ = {isa = PBXBuildFile; fileRef = FBCAFE000000000000003201 /* FBMobilerunActionsIntegrationTests.m */; };
```
In the `PBXFileReference` section (after the `FBW3CTouchActionsIntegrationTests.m` fileRef):
```
		FBCAFE000000000000003201 /* FBMobilerunActionsIntegrationTests.m */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.c.objc; path = FBMobilerunActionsIntegrationTests.m; sourceTree = "<group>"; };
```
In the group children list (after the `FBW3CTouchActionsIntegrationTests.m` group entry):
```
				FBCAFE000000000000003201 /* FBMobilerunActionsIntegrationTests.m */,
```
In the test target's `PBXSourcesBuildPhase` (after the `FBW3CTouchActionsIntegrationTests.m in Sources` line):
```
				FBCAFE000000000000003202 /* FBMobilerunActionsIntegrationTests.m in Sources */,
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `xcodebuild build-for-testing -project WebDriverAgent.xcodeproj -scheme IntegrationTests_1 -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: FAIL — compile error `no visible @interface for 'XCUIApplication' declares the selector 'fb_performMobilerunActions:error:'`.

- [ ] **Step 4: Commit**

```bash
git add WebDriverAgentTests/IntegrationTests/FBMobilerunActionsIntegrationTests.m WebDriverAgent.xcodeproj/project.pbxproj
git commit -m "test(mobilerun): add failing fast-path actions integration test"
```

---

## Task 2: Implement `fb_performMobilerunActions:error:`

**Files:**
- Modify: `WebDriverAgentLib/Categories/XCUIApplication+FBTouchAction.h`
- Modify: `WebDriverAgentLib/Categories/XCUIApplication+FBTouchAction.m`

- [ ] **Step 1: Declare the method in the header**

In `XCUIApplication+FBTouchAction.h`, add inside `@interface XCUIApplication (FBTouchAction)`, after the `fb_performW3CActions:...` declaration:

```objc
/**
 Performs a flat sequence of pointer events — the /mobilerun/actions fast path.
 Items are grouped by their optional integer 'pointerId' (default 0) into concurrent
 touch paths. Bypasses the W3C synthesizer, the element cache, and the post-gesture
 stability wait.

 @param items array of {type,x,y,duration,button,pointerId} dictionaries. 'type' is one
        of pointerDown, pointerMove, pointerUp, pause. 'duration' is in milliseconds.
 @param error populated on invalid input or synthesis failure.
 @return YES if the event was dispatched, otherwise NO.
 */
- (BOOL)fb_performMobilerunActions:(NSArray *)items error:(NSError * _Nullable*)error;
```

- [ ] **Step 2: Add imports to the implementation**

In `XCUIApplication+FBTouchAction.m`, add to the existing import block:

```objc
#import "FBErrorBuilder.h"
#import "FBMacros.h"
#import "XCPointerEventPath.h"
#import "XCSynthesizedEventRecord.h"
```

- [ ] **Step 3: Implement the method**

In `XCUIApplication+FBTouchAction.m`, inside `@implementation XCUIApplication (FBTouchAction)` (within the existing `#if !TARGET_OS_TV` block), add:

```objc
- (BOOL)fb_mobilerunPoint:(CGPoint *)outPoint fromItem:(NSDictionary *)item error:(NSError **)error
{
  id x = item[@"x"];
  id y = item[@"y"];
  if (![x isKindOfClass:NSNumber.class] || ![y isKindOfClass:NSNumber.class]) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"Action item requires numeric 'x' and 'y': %@", item]
            buildError:error];
  }
  *outPoint = CGPointMake([x doubleValue], [y doubleValue]);
  return YES;
}

- (BOOL)fb_performMobilerunActions:(NSArray *)items error:(NSError **)error
{
  if (![items isKindOfClass:NSArray.class] || 0 == items.count) {
    return [[[FBErrorBuilder builder]
             withDescription:@"Mobilerun actions must be a non-empty array"]
            buildError:error];
  }

  NSMutableDictionary<NSNumber *, XCPointerEventPath *> *paths = [NSMutableDictionary dictionary];
  NSMutableDictionary<NSNumber *, NSNumber *> *offsets = [NSMutableDictionary dictionary];
  NSMutableArray<NSNumber *> *order = [NSMutableArray array];

  for (id rawItem in items) {
    if (![rawItem isKindOfClass:NSDictionary.class]) {
      return [[[FBErrorBuilder builder]
               withDescriptionFormat:@"Each action item must be an object: %@", rawItem]
              buildError:error];
    }
    NSDictionary *item = (NSDictionary *)rawItem;

    id type = item[@"type"];
    if (![type isKindOfClass:NSString.class]) {
      return [[[FBErrorBuilder builder]
               withDescriptionFormat:@"Action item is missing a string 'type': %@", item]
              buildError:error];
    }

    NSNumber *pointerId = [item[@"pointerId"] isKindOfClass:NSNumber.class] ? item[@"pointerId"] : @0;
    double offsetMs = offsets[pointerId] ? offsets[pointerId].doubleValue : 0.0;
    double durationMs = [item[@"duration"] isKindOfClass:NSNumber.class] ? [item[@"duration"] doubleValue] : 0.0;
    XCPointerEventPath *path = paths[pointerId];

    if ([type isEqualToString:@"pause"]) {
      // No event; only advances this pointer's offset below.
    } else if ([type isEqualToString:@"pointerDown"]) {
      CGPoint point;
      if (![self fb_mobilerunPoint:&point fromItem:item error:error]) {
        return NO;
      }
      if (nil == path) {
        path = [[XCPointerEventPath alloc] initForTouchAtPoint:point offset:FBMillisToSeconds(offsetMs)];
        paths[pointerId] = path;
        [order addObject:pointerId];
      } else {
        [path pressDownAtOffset:FBMillisToSeconds(offsetMs)];
      }
    } else if ([type isEqualToString:@"pointerMove"]) {
      CGPoint point;
      if (![self fb_mobilerunPoint:&point fromItem:item error:error]) {
        return NO;
      }
      if (nil == path) {
        path = [[XCPointerEventPath alloc] initForTouchAtPoint:point offset:FBMillisToSeconds(offsetMs + durationMs)];
        paths[pointerId] = path;
        [order addObject:pointerId];
      } else {
        [path moveToPoint:point atOffset:FBMillisToSeconds(offsetMs + durationMs)];
      }
    } else if ([type isEqualToString:@"pointerUp"]) {
      if (nil == path) {
        return [[[FBErrorBuilder builder]
                 withDescriptionFormat:@"'pointerUp' for pointer %@ has no preceding 'pointerDown'", pointerId]
                buildError:error];
      }
      [path liftUpAtOffset:FBMillisToSeconds(offsetMs)];
    } else {
      return [[[FBErrorBuilder builder]
               withDescriptionFormat:@"Unsupported action type '%@'. Supported: pointerDown, pointerMove, pointerUp, pause", type]
              buildError:error];
    }

    offsets[pointerId] = @(offsetMs + durationMs);
  }

  if (0 == paths.count) {
    return [[[FBErrorBuilder builder]
             withDescription:@"No pointer events were produced by the actions"]
            buildError:error];
  }

  XCSynthesizedEventRecord *eventRecord =
    [[XCSynthesizedEventRecord alloc] initWithName:@"Mobilerun Action"
                              interfaceOrientation:self.interfaceOrientation];
  for (NSNumber *pointerId in order) {
    [eventRecord addPointerEventPath:paths[pointerId]];
  }
  return [self fb_synthesizeEvent:eventRecord error:error];
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -project WebDriverAgent.xcodeproj -scheme IntegrationTests_1 -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:WebDriverAgentTests/FBMobilerunActionsIntegrationTests`
Expected: PASS — `testTapShowsAlert`, `testRejectsNonArrayAndEmpty`, `testRejectsPointerUpWithoutDown` all green.

- [ ] **Step 5: Commit**

```bash
git add WebDriverAgentLib/Categories/XCUIApplication+FBTouchAction.h WebDriverAgentLib/Categories/XCUIApplication+FBTouchAction.m
git commit -m "feat(mobilerun): synthesize pointer gestures from a flat action array"
```

---

## Task 3: HTTP handler `FBMobilerunActionsCommands`

**Files:**
- Create: `WebDriverAgentLib/Commands/FBMobilerunActionsCommands.h` / `.m`
- Modify: `WebDriverAgent.xcodeproj/project.pbxproj` (library target wiring)

- [ ] **Step 1: Create the header**

`WebDriverAgentLib/Commands/FBMobilerunActionsCommands.h`:

```objc
/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import <WebDriverAgentLib/FBCommandHandler.h>

NS_ASSUME_NONNULL_BEGIN

@interface FBMobilerunActionsCommands : NSObject <FBCommandHandler>

@end

NS_ASSUME_NONNULL_END
```

- [ ] **Step 2: Create the implementation**

`WebDriverAgentLib/Commands/FBMobilerunActionsCommands.m`:

```objc
/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBMobilerunActionsCommands.h"

#import "FBCommandStatus.h"
#import "FBResponsePayload.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBSession.h"
#import "XCUIApplication.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIApplication+FBTouchAction.h"

@implementation FBMobilerunActionsCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute POST:@"/mobilerun/actions"] respondWithTarget:self action:@selector(handlePerformActions:)],
    [[FBRoute POST:@"/mobilerun/actions"].withoutSession respondWithTarget:self action:@selector(handlePerformActions:)],
  ];
}

#pragma mark - Commands

+ (id<FBResponsePayload>)handlePerformActions:(FBRouteRequest *)request
{
  // A top-level JSON array body arrives in request.arguments as an NSArray.
  id items = request.arguments;
  if (![items isKindOfClass:NSArray.class]) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"The request body must be a JSON array of action items"
                                                                       traceback:nil]);
  }
  XCUIApplication *app = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;
  NSError *error;
  if (![app fb_performMobilerunActions:(NSArray *)items error:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

@end
```

- [ ] **Step 3: Wire both files into the library targets in `project.pbxproj`**

Find the `FBMobilerunA11yCommands` entries: `grep -n "FBMobilerunA11yCommands" WebDriverAgent.xcodeproj/project.pbxproj` (10 lines). For each, add a sibling line directly below, replacing UUID prefix `...0030` → `...0031` and the filename `FBMobilerunA11yCommands` → `FBMobilerunActionsCommands`. The new UUIDs: `3101` (.h fileRef), `3104` (.m fileRef), `3102`/`3103` (.h-in-Headers, two targets), `3105`/`3106` (.m-in-Sources, two targets).

`PBXBuildFile` section — after the four A11y build-file lines, add:
```
		FBCAFE000000000000003102 /* FBMobilerunActionsCommands.h in Headers */ = {isa = PBXBuildFile; fileRef = FBCAFE000000000000003101 /* FBMobilerunActionsCommands.h */; };
		FBCAFE000000000000003103 /* FBMobilerunActionsCommands.h in Headers */ = {isa = PBXBuildFile; fileRef = FBCAFE000000000000003101 /* FBMobilerunActionsCommands.h */; };
		FBCAFE000000000000003105 /* FBMobilerunActionsCommands.m in Sources */ = {isa = PBXBuildFile; fileRef = FBCAFE000000000000003104 /* FBMobilerunActionsCommands.m */; };
		FBCAFE000000000000003106 /* FBMobilerunActionsCommands.m in Sources */ = {isa = PBXBuildFile; fileRef = FBCAFE000000000000003104 /* FBMobilerunActionsCommands.m */; };
```
`PBXFileReference` section — after the two A11y fileRef lines, add:
```
		FBCAFE000000000000003101 /* FBMobilerunActionsCommands.h */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.c.h; path = FBMobilerunActionsCommands.h; sourceTree = "<group>"; };
		FBCAFE000000000000003104 /* FBMobilerunActionsCommands.m */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.c.objc; path = FBMobilerunActionsCommands.m; sourceTree = "<group>"; };
```
Group children (the `Commands` group, after the two A11y lines):
```
				FBCAFE000000000000003101 /* FBMobilerunActionsCommands.h */,
				FBCAFE000000000000003104 /* FBMobilerunActionsCommands.m */,
```
Headers build phase — after the line containing `003003 /* FBMobilerunA11yCommands.h in Headers */`, add:
```
				FBCAFE000000000000003103 /* FBMobilerunActionsCommands.h in Headers */,
```
and after the line containing `003002 /* FBMobilerunA11yCommands.h in Headers */`, add:
```
				FBCAFE000000000000003102 /* FBMobilerunActionsCommands.h in Headers */,
```
Sources build phase — after the line containing `003006 /* FBMobilerunA11yCommands.m in Sources */`, add:
```
				FBCAFE000000000000003106 /* FBMobilerunActionsCommands.m in Sources */,
```
and after the line containing `003005 /* FBMobilerunA11yCommands.m in Sources */`, add:
```
				FBCAFE000000000000003105 /* FBMobilerunActionsCommands.m in Sources */,
```

- [ ] **Step 4: Verify the library still compiles**

Run: `xcodebuild build -project WebDriverAgent.xcodeproj -scheme WebDriverAgentLib -destination 'generic/platform=iOS Simulator' -quiet`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Verify the route is reachable end-to-end (optional, needs running WDA)**

With the WDA runner active on `$WDA` (e.g. `http://localhost:8100`):
```bash
curl -sS -X POST "$WDA/mobilerun/actions" -H 'Content-Type: application/json' \
  -d '[{"type":"pointerDown","x":100,"y":200},{"type":"pointerUp","x":100,"y":200}]'
```
Expected: `{"value":null,...}` (HTTP 200). A non-array body returns an invalid-argument error.

- [ ] **Step 6: Commit**

```bash
git add WebDriverAgentLib/Commands/FBMobilerunActionsCommands.h WebDriverAgentLib/Commands/FBMobilerunActionsCommands.m WebDriverAgent.xcodeproj/project.pbxproj
git commit -m "feat(mobilerun): add POST /mobilerun/actions fast-path endpoint"
```

---

## Task 4: API reference doc

**Files:**
- Create: `docs/mobilerun-actions.md`

- [ ] **Step 1: Write the reference**

Create `docs/mobilerun-actions.md` matching the style of `docs/mobilerun-screencapture.md`:

```markdown
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
the concurrent moves matching `duration`s. `pointerDown` at `offset`, `pointerMove`
completes at `offset+duration`, `pointerUp` at `offset` — identical timing to the W3C
path. A re-`pointerDown` on an existing path presses at the current location (same-spot
double-tap); insert a `pointerMove` first to re-press elsewhere.

## Examples

\`\`\`bash
# tap at (100, 200)
curl -X POST "$WDA/mobilerun/actions" -H 'Content-Type: application/json' \
  -d '[{"type":"pointerDown","x":100,"y":200},{"type":"pointerUp","x":100,"y":200}]'

# 150 ms swipe up
curl -X POST "$WDA/mobilerun/actions" -H 'Content-Type: application/json' \
  -d '[{"type":"pointerDown","x":100,"y":600},
       {"type":"pointerMove","x":100,"y":200,"duration":150},
       {"type":"pointerUp","x":100,"y":200}]'
\`\`\`

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
```

- [ ] **Step 2: Commit**

```bash
git add docs/mobilerun-actions.md
git commit -m "docs(mobilerun): add /mobilerun/actions API reference"
```

---

## Self-review notes

- **Spec coverage:** endpoint + routes (Task 3) ✓; top-level array body (Task 3) ✓; pointer-event vocabulary + per-pointer offset + multi-touch grouping (Task 2) ✓; skip envelope/cache/stability wait (Task 2) ✓; synchronous dispatch (Task 2/3) ✓; error cases (Task 2 method + Task 3 non-array) ✓; integration test (Task 1) ✓; pbxproj wiring both lib targets + test target (Tasks 1, 3) ✓; API doc (Task 4) ✓.
- **Type consistency:** the selector is `fb_performMobilerunActions:error:` in the header (Task 2 Step 1), implementation (Task 2 Step 3), and both tests/handler (Tasks 1, 3). The helper `fb_mobilerunPoint:fromItem:error:` is defined and used within the same `@implementation`. UUID blocks `3101–3106` (lib) and `3201–3202` (test) are distinct from the existing `3001–3006`.
- **Known environment dependency:** the integration run in Task 1 Step 3 / Task 2 Step 4 needs a booted simulator and the WDA test host; if unavailable, fall back to `build-for-testing` for a compile-only gate and run the behavioral assertion on CI / a connected device.
```

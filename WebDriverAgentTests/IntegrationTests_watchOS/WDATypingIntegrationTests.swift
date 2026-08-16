/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Covers /element/:uuid/value, /element/:uuid/clear, and /wda/keyboard/dismiss.
///
/// KNOWN LIMITATION (see XCUIElement+FBTyping.m): the keyboard opens and the field gets focus,
/// but no keystrokes land. Wrapped in XCTExpectFailure so this re-verifies itself and starts
/// failing loudly the moment it starts working, instead of silently staying stale.
final class WDATypingIntegrationTests: WDAWatchIntegrationTestCase {
  func testSetValueOpensTheKeyboardAndAttemptsToTypeIntoTheField() throws {
    let fieldId = try findElement(byAccessibilityId: "typingField")
    XCTAssertEqual(try attributeValue(fieldId, "value"), "Type here", "expected the untouched placeholder")

    let setValueResponse = try client.post("/session/\(sessionId!)/element/\(fieldId)/value", body: [
      "value": ["h", "i"]
    ])
    XCTAssertEqual(setValueResponse.statusCode, 200, "the route itself should not error even though typing doesn't land")

    XCTExpectFailure("watchOS keystroke delivery into the on-screen keyboard is a known unresolved limitation") {
      let value = try? attributeValue(fieldId, "value")
      XCTAssertEqual(value, "hi")
    }

    // Back out so later tests start clean.
    if let cancelId = try? findElement(byAccessibilityId: "Cancel") {
      _ = try? client.post("/session/\(sessionId!)/element/\(cancelId)/click")
    }
  }

  func testClearingAnAlreadyEmptyFieldSucceeds() throws {
    // Clearing an empty field short-circuits, so this works despite the typing limitation.
    let fieldId = try findElement(byAccessibilityId: "typingField")
    let clearResponse = try client.post("/session/\(sessionId!)/element/\(fieldId)/clear")
    XCTAssertEqual(clearResponse.statusCode, 200)
  }

  func testDismissKeyboardRouteRespondsWithoutCrashingTheServer() throws {
    // Only asserts the route round-trips cleanly, not that dismissal actually happens.
    let fieldId = try findElement(byAccessibilityId: "typingField")
    try client.post("/session/\(sessionId!)/element/\(fieldId)/click")
    Thread.sleep(forTimeInterval: 1)

    _ = try client.post("/session/\(sessionId!)/wda/keyboard/dismiss")

    // Back out regardless of whether dismiss actually closed the sheet.
    if let cancelId = try? findElement(byAccessibilityId: "Cancel") {
      _ = try? client.post("/session/\(sessionId!)/element/\(cancelId)/click")
    }
  }
}

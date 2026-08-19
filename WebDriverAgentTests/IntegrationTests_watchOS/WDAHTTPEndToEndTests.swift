/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// The small set of tests that actually drive a real, separately running
/// WebDriverAgentRunner_watchOS server over HTTP, the way a real client (Appium, curl) would -
/// see WDAWatchHTTPClient. Everything else in this suite calls WebDriverAgentLib_watchOS's
/// categories directly in-process (see WDAWatchInProcessTestCase and its subclasses), which is
/// far faster but never exercises the actual server: route dispatch, JSON request/response
/// encoding, session/element-UUID bookkeeping. This file, plus WDASessionIntegrationTests and
/// WDAUnknownCommandIntegrationTests (which are inherently server/session-layer concerns with no
/// in-process equivalent to call instead), are what still needs a live server in CI.
final class WDAHTTPEndToEndTests: WDAWatchIntegrationTestCase {
  func testFindClickAndVerifyOverHTTP() throws {
    let buttonId = try findElement(byAccessibilityId: "tapMeButton")
    let labelId = try findElement(byAccessibilityId: "resultLabel")
    XCTAssertEqual(try attributeValue(labelId, "label"), "Idle")

    let clickResponse = try client.post("/session/\(sessionId!)/element/\(buttonId)/click")
    XCTAssertEqual(clickResponse.statusCode, 200)

    // Re-find: element UUIDs aren't stable across snapshots, and the label just changed.
    let updatedLabelId = try findElement(byAccessibilityId: "resultLabel")
    XCTAssertEqual(try attributeValue(updatedLabelId, "label"), "Tapped")
  }

  func testFindElementThatDoesNotExistReturnsAnError() throws {
    let response = try client.post("/session/\(sessionId!)/element", body: [
      "using": "accessibility id",
      "value": "thisElementDoesNotExist",
    ])
    XCTAssertNotEqual(response.statusCode, 200)
  }

  func testClickingAnElementThatDoesNotExistReturnsAnError() throws {
    let response = try client.post("/session/\(sessionId!)/element/00000000-0000-0000-0000-000000000000/click")
    XCTAssertNotEqual(response.statusCode, 200)
  }

  func testRotateDigitalCrownMissingDelta() throws {
    // Argument validation happens before the dynamic dispatch check, so this is always a 400.
    let response = try client.post("/session/\(sessionId!)/wda/rotateDigitalCrown")
    XCTAssertEqual(response.statusCode, 400)
  }

  func testPerformHandGestureMissingName() throws {
    let response = try client.post("/session/\(sessionId!)/wda/performHandGesture")
    XCTAssertEqual(response.statusCode, 400)
  }
}

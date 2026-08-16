/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Covers FBElementCommands' read-only element/window attribute routes.
final class WDAElementAttributeIntegrationTests: WDAWatchIntegrationTestCase {
  func testWindowSizeAndRect() throws {
    let sizeResponse = try client.get("/session/\(sessionId!)/window/size")
    XCTAssertEqual(sizeResponse.statusCode, 200)
    XCTAssertGreaterThan(sizeResponse.valueDict?["width"] as? Double ?? 0, 0)
    XCTAssertGreaterThan(sizeResponse.valueDict?["height"] as? Double ?? 0, 0)

    let rectResponse = try client.get("/session/\(sessionId!)/window/rect")
    XCTAssertEqual(rectResponse.statusCode, 200)
    XCTAssertGreaterThan(rectResponse.valueDict?["width"] as? Double ?? 0, 0)
  }

  func testButtonAttributes() throws {
    let buttonId = try findElement(byAccessibilityId: "tapMeButton")

    let enabledResponse = try client.get("/session/\(sessionId!)/element/\(buttonId)/enabled")
    XCTAssertEqual(enabledResponse.value as? Bool, true)

    let displayedResponse = try client.get("/session/\(sessionId!)/element/\(buttonId)/displayed")
    XCTAssertEqual(displayedResponse.value as? Bool, true)

    let rectResponse = try client.get("/session/\(sessionId!)/element/\(buttonId)/rect")
    XCTAssertEqual(rectResponse.statusCode, 200)
    XCTAssertGreaterThan(rectResponse.valueDict?["width"] as? Double ?? 0, 0)

    let nameResponse = try client.get("/session/\(sessionId!)/element/\(buttonId)/name")
    XCTAssertEqual(nameResponse.valueString, "XCUIElementTypeButton")

    let labelResponse = try client.get("/session/\(sessionId!)/element/\(buttonId)/attribute/label")
    XCTAssertEqual(labelResponse.valueString, "Tap Me")

    let accessibleResponse = try client.get("/session/\(sessionId!)/wda/element/\(buttonId)/accessible")
    XCTAssertEqual(accessibleResponse.statusCode, 200)
  }

  func testResultLabelTextAndSelectedState() throws {
    let labelId = try findElement(byAccessibilityId: "resultLabel")

    let textResponse = try client.get("/session/\(sessionId!)/element/\(labelId)/text")
    XCTAssertEqual(textResponse.valueString, "Idle")

    let selectedResponse = try client.get("/session/\(sessionId!)/element/\(labelId)/selected")
    XCTAssertEqual(selectedResponse.statusCode, 200)
    XCTAssertEqual(selectedResponse.value as? Bool, false)
  }
}

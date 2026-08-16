/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Covers /element/:uuid/click - the only tap-like interaction registered on watchOS
/// (gesture synthesis routes aren't).
final class WDAClickIntegrationTests: WDAWatchIntegrationTestCase {
  func testClickingButtonUpdatesTheResultLabel() throws {
    let labelId = try findElement(byAccessibilityId: "resultLabel")
    XCTAssertEqual(try attributeValue(labelId, "label"), "Idle")

    let buttonId = try findElement(byAccessibilityId: "tapMeButton")
    let clickResponse = try client.post("/session/\(sessionId!)/element/\(buttonId)/click")
    XCTAssertEqual(clickResponse.statusCode, 200)

    // Re-find: element UUIDs aren't stable across snapshots, and the label just changed.
    let updatedLabelId = try findElement(byAccessibilityId: "resultLabel")
    XCTAssertEqual(try attributeValue(updatedLabelId, "label"), "Tapped")
  }

  func testClickingAnElementThatDoesNotExistReturnsAnError() throws {
    let response = try client.post("/session/\(sessionId!)/element/00000000-0000-0000-0000-000000000000/click")
    XCTAssertNotEqual(response.statusCode, 200)
  }
}

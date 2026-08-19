/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Covers the FBElement attribute properties (wdEnabled/wdVisible/wdRect/wdType/wdLabel/
/// wdSelected/wdAccessible/fb_valueForWDAttributeName:) directly, in-process - the same
/// properties FBElementCommands' attribute routes read from.
final class WDAElementAttributeIntegrationTests: WDAWatchInProcessTestCase {
  // All reads, no taps/typing - reuse the same running app across the whole class.
  override class var relaunchForEachTest: Bool { false }

  func testWindowSizeAndRect() {
    XCTAssertGreaterThan(app.wdFrame.width, 0)
    XCTAssertGreaterThan(app.wdFrame.height, 0)
  }

  func testButtonAttributes() {
    let button = app.buttons["tapMeButton"]
    XCTAssertTrue(button.isWDEnabled)
    XCTAssertTrue(button.isWDVisible)
    XCTAssertGreaterThan(button.wdRect["width"] as? Double ?? 0, 0)
    XCTAssertEqual(button.wdType, "XCUIElementTypeButton")
    XCTAssertEqual(button.wdLabel, "Tap Me")
    XCTAssertEqual(button.fb_value(forWDAttributeName: "label") as? String, "Tap Me")
    XCTAssertTrue(button.isWDAccessible)
  }

  func testResultLabelTextAndSelectedState() {
    let label = app.staticTexts["resultLabel"]
    XCTAssertEqual(label.wdValue ?? label.wdLabel, "Idle")
    XCTAssertFalse(label.isWDSelected)
  }
}

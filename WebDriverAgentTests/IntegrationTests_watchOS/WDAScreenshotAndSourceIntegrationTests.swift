/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest
// XCUIAutomation is a separate module on newer SDKs but folded into XCTest on older ones
// (Xcode 15.4) - guard the import so this builds on both.
#if canImport(XCUIAutomation)
import XCUIAutomation
#endif

/// Covers device/element screenshots and page source, calling XCUIDevice+FBHelpers/
/// XCUIApplication+FBHelpers and plain XCTest APIs directly in-process.
final class WDAScreenshotAndSourceIntegrationTests: WDAWatchInProcessTestCase {
  // All reads, no taps/typing - reuse the same running app across the whole class.
  override class var relaunchForEachTest: Bool { false }

  private static let pngMagicBytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

  private func assertLooksLikeAPNG(_ data: Data?, file: StaticString = #filePath, line: UInt = #line) {
    guard let data = data else {
      return XCTFail("No screenshot data returned", file: file, line: line)
    }
    XCTAssertGreaterThan(data.count, Self.pngMagicBytes.count, file: file, line: line)
    XCTAssertEqual(Array(data.prefix(Self.pngMagicBytes.count)), Self.pngMagicBytes, "not a PNG", file: file, line: line)
  }

  func testDeviceScreenshot() throws {
    let data = try XCUIDevice.shared.fb_screenshot()
    assertLooksLikeAPNG(data)
  }

  func testElementScreenshot() {
    let provider: XCUIScreenshotProviding = app.buttons["tapMeButton"]
    assertLooksLikeAPNG(provider.screenshot().pngRepresentation)
  }

  func testPageSourceContainsTheKnownElements() {
    guard let xml = app.fb_xmlRepresentation() else {
      return XCTFail("No XML source returned")
    }
    XCTAssertTrue(xml.contains("tapMeButton"))
    XCTAssertTrue(xml.contains("resultLabel"))
    XCTAssertTrue(xml.contains("typingField"))
  }

  func testAccessibleSource() {
    XCTAssertFalse(app.fb_accessibilityTree().isEmpty)
  }
}

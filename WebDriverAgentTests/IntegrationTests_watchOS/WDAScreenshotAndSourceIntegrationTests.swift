/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Covers device/element screenshots and /source, /wda/accessibleSource.
final class WDAScreenshotAndSourceIntegrationTests: WDAWatchIntegrationTestCase {
  private static let pngMagicBytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

  private func assertLooksLikeAPNG(_ base64String: String?, file: StaticString = #filePath, line: UInt = #line) {
    guard let base64String = base64String, let data = Data(base64Encoded: base64String) else {
      return XCTFail("Response value was not base64 data", file: file, line: line)
    }
    XCTAssertGreaterThan(data.count, Self.pngMagicBytes.count, file: file, line: line)
    XCTAssertEqual(Array(data.prefix(Self.pngMagicBytes.count)), Self.pngMagicBytes, "response was not a PNG", file: file, line: line)
  }

  func testDeviceScreenshot() throws {
    let response = try client.get("/session/\(sessionId!)/screenshot")
    XCTAssertEqual(response.statusCode, 200)
    assertLooksLikeAPNG(response.valueString)
  }

  func testElementScreenshot() throws {
    let buttonId = try findElement(byAccessibilityId: "tapMeButton")
    let response = try client.get("/session/\(sessionId!)/element/\(buttonId)/screenshot")
    XCTAssertEqual(response.statusCode, 200)
    assertLooksLikeAPNG(response.valueString)
  }

  func testPageSourceContainsTheKnownElements() throws {
    let response = try client.get("/session/\(sessionId!)/source?format=xml")
    XCTAssertEqual(response.statusCode, 200)
    guard let xml = response.valueString else {
      return XCTFail("No XML source returned")
    }
    XCTAssertTrue(xml.contains("tapMeButton"))
    XCTAssertTrue(xml.contains("resultLabel"))
    XCTAssertTrue(xml.contains("typingField"))
  }

  func testAccessibleSource() throws {
    let response = try client.get("/session/\(sessionId!)/wda/accessibleSource")
    XCTAssertEqual(response.statusCode, 200)
    XCTAssertNotNil(response.value)
  }
}

/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Creates a fresh WDA session against IntegrationApp_watchOS per test, so each starts clean.
class WDAWatchIntegrationTestCase: XCTestCase {
  static let integrationAppBundleId = ProcessInfo.processInfo.environment["WDA_TEST_BUNDLE_ID"]
    ?? "com.facebook.wda.IntegrationApp.watchOS"

  let client = WDAWatchHTTPClient()
  var sessionId: String!

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    do {
      let response = try client.post("/session", body: [
        "capabilities": ["alwaysMatch": ["bundleId": Self.integrationAppBundleId]]
      ])
      guard response.statusCode == 200, let sessionId = response.valueDict?["sessionId"] as? String else {
        XCTFail("Failed to create session: \(String(describing: response.json))")
        return
      }
      self.sessionId = sessionId
    } catch {
      XCTFail("Failed to create session: \(error)")
    }
  }

  override func tearDown() {
    if let sessionId = sessionId {
      _ = try? client.delete("/session/\(sessionId)")
    }
    super.tearDown()
  }

  /// Finds an element by accessibility id and returns its WDA element UUID.
  @discardableResult
  func findElement(byAccessibilityId accessibilityId: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
    let response = try client.post("/session/\(sessionId!)/element", body: [
      "using": "accessibility id",
      "value": accessibilityId,
    ])
    guard response.statusCode == 200, let elementId = response.valueDict?["ELEMENT"] as? String else {
      XCTFail("Could not find element '\(accessibilityId)': \(String(describing: response.json))", file: file, line: line)
      throw WDAWatchHTTPClient.ClientError.requestFailed("element not found")
    }
    return elementId
  }

  func attributeValue(_ elementId: String, _ name: String) throws -> String? {
    let response = try client.get("/session/\(sessionId!)/element/\(elementId)/attribute/\(name)")
    return response.valueString
  }
}

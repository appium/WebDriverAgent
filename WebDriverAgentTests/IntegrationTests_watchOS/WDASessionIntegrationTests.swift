/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Covers FBSessionCommands. Manages its own session lifecycle per test, since that's what's
/// under test here, rather than using WDAWatchIntegrationTestCase.
final class WDASessionIntegrationTests: XCTestCase {
  let client = WDAWatchHTTPClient()

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  func testStatusIsReadyWithoutASession() throws {
    let response = try client.get("/status")
    XCTAssertEqual(response.statusCode, 200)
    XCTAssertEqual(response.valueDict?["ready"] as? Bool, true)
    XCTAssertEqual(response.valueDict?["state"] as? String, "success")
  }

  func testHealthCheck() throws {
    let response = try client.get("/wda/healthcheck")
    XCTAssertEqual(response.statusCode, 200)
  }

  func testCreateGetActiveAndDeleteSessionLifecycle() throws {
    let createResponse = try client.post("/session", body: [
      "capabilities": ["alwaysMatch": ["bundleId": WDAWatchIntegrationTestCase.integrationAppBundleId]]
    ])
    XCTAssertEqual(createResponse.statusCode, 200)
    guard let sessionId = createResponse.valueDict?["sessionId"] as? String else {
      return XCTFail("No sessionId in create-session response: \(String(describing: createResponse.json))")
    }
    XCTAssertFalse(sessionId.isEmpty)

    let activeResponse = try client.get("/session/\(sessionId)")
    XCTAssertEqual(activeResponse.statusCode, 200)
    XCTAssertEqual(activeResponse.valueDict?["sessionId"] as? String, sessionId)

    let deleteResponse = try client.delete("/session/\(sessionId)")
    XCTAssertEqual(deleteResponse.statusCode, 200)
  }

  func testTimeoutsAndAppiumSettingsRoundTrip() throws {
    let createResponse = try client.post("/session", body: [
      "capabilities": ["alwaysMatch": ["bundleId": WDAWatchIntegrationTestCase.integrationAppBundleId]]
    ])
    guard let sessionId = createResponse.valueDict?["sessionId"] as? String else {
      return XCTFail("No sessionId in create-session response")
    }
    defer { _ = try? client.delete("/session/\(sessionId)") }

    let timeoutsResponse = try client.post("/session/\(sessionId)/timeouts", body: ["implicit": 500])
    XCTAssertEqual(timeoutsResponse.statusCode, 200)

    let getSettingsResponse = try client.get("/session/\(sessionId)/appium/settings")
    XCTAssertEqual(getSettingsResponse.statusCode, 200)
    XCTAssertNotNil(getSettingsResponse.valueDict)

    let setSettingsResponse = try client.post("/session/\(sessionId)/appium/settings", body: [
      "settings": ["shouldUseCompactResponses": false]
    ])
    XCTAssertEqual(setSettingsResponse.statusCode, 200)
  }
}

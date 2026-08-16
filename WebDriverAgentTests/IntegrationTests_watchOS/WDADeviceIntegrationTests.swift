/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Covers device-info and location routes. These only read device state or set a simulated
/// GPS fix, so unlike /wda/lock or /wda/voiceOver/enable, they won't disrupt later tests.
final class WDADeviceIntegrationTests: WDAWatchIntegrationTestCase {
  func testDeviceInfo() throws {
    let response = try client.get("/session/\(sessionId!)/wda/device/info")
    XCTAssertEqual(response.statusCode, 200)
    XCTAssertFalse((response.valueDict?["name"] as? String ?? "").isEmpty)
    XCTAssertFalse((response.valueDict?["model"] as? String ?? "").isEmpty)
  }

  func testActiveAppInfo() throws {
    let response = try client.get("/session/\(sessionId!)/wda/activeAppInfo")
    XCTAssertEqual(response.statusCode, 200)
    XCTAssertEqual(response.valueDict?["bundleId"] as? String, Self.integrationAppBundleId)
    XCTAssertGreaterThan(response.valueDict?["pid"] as? Int ?? 0, 0)
  }

  func testDeviceLocation() throws {
    let response = try client.get("/session/\(sessionId!)/wda/device/location")
    XCTAssertEqual(response.statusCode, 200)
    XCTAssertNotNil(response.valueDict?["latitude"])
    XCTAssertNotNil(response.valueDict?["authorizationStatus"])
  }

  func testSimulatedLocationRoundTrip() throws {
    let setResponse = try client.post("/session/\(sessionId!)/wda/simulatedLocation", body: [
      "latitude": 37.3230,
      "longitude": -122.0322,
    ])
    XCTAssertEqual(setResponse.statusCode, 200)

    let getResponse = try client.get("/session/\(sessionId!)/wda/simulatedLocation")
    XCTAssertEqual(getResponse.statusCode, 200)
    XCTAssertEqual(getResponse.valueDict?["latitude"] as? Double ?? 0, 37.3230, accuracy: 0.001)
    XCTAssertEqual(getResponse.valueDict?["longitude"] as? Double ?? 0, -122.0322, accuracy: 0.001)

    let clearResponse = try client.delete("/session/\(sessionId!)/wda/simulatedLocation")
    XCTAssertEqual(clearResponse.statusCode, 200)
  }
}

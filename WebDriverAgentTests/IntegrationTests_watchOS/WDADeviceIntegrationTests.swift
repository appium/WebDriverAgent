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

  /// rotateDigitalCrownByDelta:/performHandGesture: were only added to the SDK in Xcode 16.3 - WDA calls
  /// them dynamically (NSInvocation) so it keeps building on older Xcode too, but they only actually work
  /// when the toolchain that built this very test bundle (same build as the runner) is new enough. Checked
  /// the same way WDA itself does, via responds(to:), rather than hardcoding an Xcode/OS version number here.
  private var supportsDigitalCrownAndHandGesture: Bool {
    XCUIDevice.shared.responds(to: Selector(("rotateDigitalCrownByDelta:")))
  }

  func testRotateDigitalCrown() throws {
    let response = try client.post("/session/\(sessionId!)/wda/rotateDigitalCrown", body: [
      "delta": 0.2,
      "velocity": 1.0,
    ])
    XCTAssertEqual(response.statusCode, supportsDigitalCrownAndHandGesture ? 200 : 500)
  }

  func testRotateDigitalCrownDefaultVelocity() throws {
    let response = try client.post("/session/\(sessionId!)/wda/rotateDigitalCrown", body: [
      "delta": -0.2,
    ])
    XCTAssertEqual(response.statusCode, supportsDigitalCrownAndHandGesture ? 200 : 500)
  }

  func testRotateDigitalCrownMissingDelta() throws {
    // Argument validation happens before the dynamic dispatch check, so this is always a 400.
    let response = try client.post("/session/\(sessionId!)/wda/rotateDigitalCrown")
    XCTAssertEqual(response.statusCode, 400)
  }

  func testPerformHandGestureDoubleTap() throws {
    let response = try client.post("/session/\(sessionId!)/wda/performHandGesture", body: [
      "name": "doubleTap",
    ])
    XCTAssertEqual(response.statusCode, supportsDigitalCrownAndHandGesture ? 200 : 500)
  }

  func testPerformHandGestureFlick() throws {
    let response = try client.post("/session/\(sessionId!)/wda/performHandGesture", body: [
      "name": "flick",
    ])
    // flick additionally needs watchOS 26+ (still internally versioned 12.0 pre-rename) on top of the
    // Xcode 16.3+ toolchain floor - below that OS version it isn't even advertised as a supported name,
    // so the server rejects it the same way it would reject any other unknown gesture name.
    if #available(watchOS 12.0, *), supportsDigitalCrownAndHandGesture {
      XCTAssertEqual(response.statusCode, 200)
    } else {
      XCTAssertEqual(response.statusCode, 500)
    }
  }

  func testPerformHandGestureUnsupportedName() throws {
    // Not a real gesture name in any environment, so always rejected regardless of toolchain/OS version.
    let response = try client.post("/session/\(sessionId!)/wda/performHandGesture", body: [
      "name": "clench",
    ])
    XCTAssertEqual(response.statusCode, 500)
  }

  func testPerformHandGestureMissingName() throws {
    let response = try client.post("/session/\(sessionId!)/wda/performHandGesture")
    XCTAssertEqual(response.statusCode, 400)
  }
}

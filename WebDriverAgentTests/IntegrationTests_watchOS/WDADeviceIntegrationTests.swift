/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import CoreLocation
import WatchKit
import XCTest

/// Covers device-info, active-app-info, simulated location, digital crown rotation, and hand
/// gesture, calling the same underlying APIs FBCustomCommands/XCUIDevice+FBHelpers use directly
/// in-process. The real (non-simulated) GPS location route and the two pure argument-validation
/// cases (missing delta/gesture name, rejected before any category method is even called) aren't
/// WDA category behavior, so they're not covered here.
final class WDADeviceIntegrationTests: WDAWatchInProcessTestCase {
  func testDeviceInfo() {
    XCTAssertFalse(WKInterfaceDevice.current().name.isEmpty)
    XCTAssertFalse(WKInterfaceDevice.current().model.isEmpty)
  }

  func testActiveAppInfo() {
    let apps = XCUIApplication.fb_activeAppsInfo()
    let ourApp = apps.first { $0["bundleId"] as? String == WDAWatchInProcessTestCase.integrationAppBundleId }
    XCTAssertNotNil(ourApp)
    XCTAssertGreaterThan(ourApp?["pid"] as? Int ?? 0, 0)
  }

  func testSimulatedLocationRoundTrip() throws {
    let location = CLLocation(latitude: 37.3230, longitude: -122.0322)
    try XCUIDevice.shared.fb_setSimulatedLocation(location)

    let fetched = try XCUIDevice.shared.fb_getSimulatedLocation()
    XCTAssertEqual(fetched.coordinate.latitude, 37.3230, accuracy: 0.001)
    XCTAssertEqual(fetched.coordinate.longitude, -122.0322, accuracy: 0.001)

    try XCUIDevice.shared.fb_clearSimulatedLocation()
  }

  /// rotateDigitalCrownByDelta:/performHandGesture: were only added to the SDK in Xcode 16.3 - WDA calls
  /// them dynamically (NSInvocation) so it keeps building on older Xcode too, but they only actually work
  /// when the toolchain that built this very test bundle (same build as the runner) is new enough. Checked
  /// the same way WDA itself does, via responds(to:), rather than hardcoding an Xcode/OS version number here.
  private var supportsDigitalCrownAndHandGesture: Bool {
    XCUIDevice.shared.responds(to: NSSelectorFromString("rotateDigitalCrownByDelta:"))
  }

  private func assertSucceeds(_ expectedToSucceed: Bool, file: StaticString = #filePath, line: UInt = #line, _ body: () throws -> Void) {
    do {
      try body()
      XCTAssertTrue(expectedToSucceed, "expected this to throw, but it didn't", file: file, line: line)
    } catch {
      XCTAssertFalse(expectedToSucceed, "expected this to succeed, but it threw \(error)", file: file, line: line)
    }
  }

  func testRotateDigitalCrown() {
    assertSucceeds(supportsDigitalCrownAndHandGesture) {
      try XCUIDevice.shared.fb_rotateDigitalCrown(0.2, velocity: 1.0)
    }
  }

  func testPerformHandGestureDoubleTap() {
    assertSucceeds(supportsDigitalCrownAndHandGesture) {
      try XCUIDevice.shared.fb_performHandGesture("doubleTap")
    }
  }

  func testPerformHandGestureFlick() {
    // flick additionally needs watchOS 26+ (still internally versioned 12.0 pre-rename) on top of the
    // Xcode 16.3+ toolchain floor - below that OS version it isn't even advertised as a supported name,
    // so the server rejects it the same way it would reject any other unknown gesture name.
    let shouldSucceed: Bool
    if #available(watchOS 12.0, *) {
      shouldSucceed = supportsDigitalCrownAndHandGesture
    } else {
      shouldSucceed = false
    }
    assertSucceeds(shouldSucceed) {
      try XCUIDevice.shared.fb_performHandGesture("flick")
    }
  }

  func testPerformHandGestureUnsupportedName() {
    // Not a real gesture name in any environment, so always rejected regardless of toolchain/OS version.
    assertSucceeds(false) {
      try XCUIDevice.shared.fb_performHandGesture("clench")
    }
  }
}

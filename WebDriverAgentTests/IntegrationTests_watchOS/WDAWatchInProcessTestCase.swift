/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Base class for the watchOS integration tests: these call WebDriverAgentLib_watchOS's own
/// categories directly (fb_descendantsMatchingClassName:, wdEnabled, fb_activeAppsInfo, etc.),
/// the same way the iOS/tvOS integration tests do, rather than driving a separately running
/// WebDriverAgentRunner_watchOS server over HTTP (see git history for that approach - dropped as
/// not worth the added CI complexity; use the functional/e2e test suite for real-server coverage).
class WDAWatchInProcessTestCase: XCTestCase {
  static let integrationAppBundleId = ProcessInfo.processInfo.environment["WDA_TEST_BUNDLE_ID"]
    ?? "com.facebook.wda.IntegrationApp.watchOS"

  let app = XCUIApplication()

  /// Override to return false for a suite whose tests are all pure reads that never mutate the
  /// app's UI state (find, attributes, screenshots, source, ...) - the app then launches once for
  /// the whole class instead of once per test method, which is significantly faster. Defaults to
  /// true (relaunch every test) since that's the safe choice for any suite whose tests tap,
  /// type, or otherwise change what's on screen - or depend on a specific starting state, like
  /// resultLabel reading "Idle".
  class var relaunchForEachTest: Bool { true }

  // XCTest always runs one class's methods as a contiguous group, never interleaved with another
  // class's - so "have we seen this class's ObjectIdentifier before" reliably means "is this the
  // first test method of this class to run this session", regardless of test order randomization.
  // Shared static storage keyed per-class, since a plain `static var` in the base class would be
  // one slot shared by every subclass, not one per subclass.
  private static var classesAlreadyLaunched = Set<ObjectIdentifier>()

  override func setUp() {
    super.setUp()
    continueAfterFailure = false

    let isFirstTestForThisClass = Self.classesAlreadyLaunched.insert(ObjectIdentifier(Self.self)).inserted
    // Reuse the running app only if: this suite opted in, this isn't the class's first test
    // (every class still gets one guaranteed-clean launch, regardless of what a previous class
    // left on screen), and the isRunning check confirms the app didn't crash/background since.
    let canReuseRunningApp = !Self.relaunchForEachTest && !isFirstTestForThisClass && app.state == .runningForeground
    if !canReuseRunningApp {
      app.launch()
    }
    XCTAssertTrue(app.buttons["tapMeButton"].waitForExistence(timeout: 15))
  }
}

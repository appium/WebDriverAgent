/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Covers FBAlert's no-alert-present behavior directly, in-process. IntegrationApp_watchOS never
/// presents a real alert, so this only exercises the "no alert open" path (`text`/`buttonLabels`
/// both just return nil - no HTTP-error-style throw at this layer), not the success path.
final class WDAAlertIntegrationTests: WDAWatchInProcessTestCase {
  // All reads, no taps/typing - reuse the same running app across the whole class.
  override class var relaunchForEachTest: Bool { false }

  func testAlertTextWithNoAlertPresentReturnsNil() {
    XCTAssertNil(FBAlert(application: app).text())
  }

  func testAlertButtonsWithNoAlertPresentReturnsNil() {
    XCTAssertNil(FBAlert(application: app).buttonLabels())
  }
}

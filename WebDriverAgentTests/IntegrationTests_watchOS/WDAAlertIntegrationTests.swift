/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Covers FBAlertViewCommands' error path - IntegrationApp_watchOS never presents a real alert,
/// so this only exercises the "no alert open" error, not the success path.
final class WDAAlertIntegrationTests: WDAWatchIntegrationTestCase {
  func testAlertTextWithNoAlertPresentReturnsAnError() throws {
    let response = try client.get("/session/\(sessionId!)/alert/text")
    XCTAssertNotEqual(response.statusCode, 200)
  }

  func testAlertButtonsWithNoAlertPresentReturnsAnError() throws {
    let response = try client.get("/session/\(sessionId!)/wda/alert/buttons")
    XCTAssertNotEqual(response.statusCode, 200)
  }
}

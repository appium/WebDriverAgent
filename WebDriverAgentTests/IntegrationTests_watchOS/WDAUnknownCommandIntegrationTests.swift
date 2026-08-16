/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Covers the catch-all 404 routes and the OPTIONS ping route - neither needs a session.
final class WDAUnknownCommandIntegrationTests: XCTestCase {
  let client = WDAWatchHTTPClient()

  func testUnknownRouteReturnsAnError() throws {
    let response = try client.get("/this/route/does/not/exist")
    XCTAssertNotEqual(response.statusCode, 200)
  }

  func testPing() throws {
    let response = try client.send("OPTIONS", "/anything")
    XCTAssertEqual(response.statusCode, 200)
  }
}

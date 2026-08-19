/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Covers /element/:uuid/click, which on watchOS (like iOS) is just standard XCTest `-tap`
/// (see FBElementCommands.handleClick:) - so this just calls `.tap()` directly, the same way
/// the iOS/tvOS integration tests do. The "click a nonexistent element UUID" case isn't a `tap`
/// behavior at all (it's FBElementCache's UUID-lookup failure), so it's covered by the HTTP
/// end-to-end tests instead, where there's an actual UUID/route layer to miss against.
final class WDAClickIntegrationTests: WDAWatchInProcessTestCase {
  func testClickingButtonUpdatesTheResultLabel() {
    let label = app.staticTexts["resultLabel"]
    XCTAssertEqual(label.wdValue ?? label.wdLabel, "Idle")

    app.buttons["tapMeButton"].tap()

    XCTAssertEqual(label.wdValue ?? label.wdLabel, "Tapped")
  }
}

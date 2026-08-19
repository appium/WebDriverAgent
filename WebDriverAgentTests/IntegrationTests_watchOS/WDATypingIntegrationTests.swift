/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Covers XCUIElement+FBTyping (set value/clear) and the keyboard-dismiss helper, calling them
/// directly in-process instead of over HTTP.
///
/// KNOWN LIMITATION (see XCUIElement+FBTyping.m): the keyboard opens and the field gets focus,
/// but no keystrokes land. Wrapped in XCTExpectFailure so this re-verifies itself and starts
/// failing loudly the moment it starts working, instead of silently staying stale.
final class WDATypingIntegrationTests: WDAWatchInProcessTestCase {
  // watchOS classifies an inline TextField's element type differently across OS versions (e.g.
  // a button-styled placeholder pre-tap on some versions, .textField on others), so look it up
  // by identifier across all types rather than filtering through app.textFields.
  private var typingField: XCUIElement { app.descendants(matching: .any)["typingField"] }

  private func backOutOfKeyboardIfPresented() {
    let cancel = app.buttons["Cancel"]
    if cancel.waitForExistence(timeout: 2) {
      cancel.tap()
    }
  }

  func testSetValueOpensTheKeyboardAndAttemptsToTypeIntoTheField() {
    let field = typingField

    // Some watchOS versions (confirmed: 10.5) don't expose an inline TextField's placeholder via
    // accessibility until it's been focused at least once, so this can legitimately read nil.
    XCTExpectFailure(
      "watchOS can omit an unfocused TextField's placeholder from the accessibility tree",
      options: .nonStrict()
    ) {
      XCTAssertEqual(field.wdValue ?? field.wdPlaceholderValue, "Type here")
    }

    // fb_typeText taps to focus internally if needed, but watchOS's full-screen keyboard sheet
    // transition can outlast its short internal settle wait - tap and wait for the sheet
    // ourselves first to shrink (not eliminate) the race.
    field.tap()
    _ = app.buttons["Cancel"].waitForExistence(timeout: 5)

    // Both possible failure modes - typeText: recording a "no keyboard focus" issue internally
    // if the sheet transition is still lagging, or it landing focus fine but the keystrokes
    // themselves not registering - are the same known watchOS limitation, so both are expected
    // here. If this ever starts reliably working, XCTExpectFailure itself starts failing loudly.
    XCTExpectFailure("watchOS keystroke delivery into the on-screen keyboard is a known unresolved limitation") {
      _ = try? field.fb_typeText("hi", shouldClear: false)
      XCTAssertEqual(field.wdValue, "hi")
    }

    backOutOfKeyboardIfPresented()
  }

  func testClearingAnAlreadyEmptyFieldSucceeds() throws {
    // Clearing an empty field short-circuits, so this works despite the typing limitation.
    try typingField.fb_clearText()
  }

  func testDismissKeyboardDoesNotCrashTheApp() {
    // Only asserts the call round-trips cleanly, not that dismissal actually happens.
    typingField.tap()

    _ = try? app.fb_dismissKeyboard(withKeyNames: nil)

    backOutOfKeyboardIfPresented()
  }
}

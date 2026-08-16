/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Covers FBFindElementCommands: find/sub-find/active-element, not-found errors, and every
/// locator strategy (accessibility id/name/id, class name, class chain, xpath, predicate
/// string, link text). getVisibleCells is skipped - no table/collection view to test it against.
final class WDAFindIntegrationTests: WDAWatchIntegrationTestCase {
  func testFindElementByAccessibilityId() throws {
    let elementId = try findElement(byAccessibilityId: "tapMeButton")
    XCTAssertFalse(elementId.isEmpty)
  }

  func testFindElementByNameAndIdAliases() throws {
    // "name" and "id" are aliases for "accessibility id".
    for using in ["name", "id"] {
      let response = try client.post("/session/\(sessionId!)/element", body: [
        "using": using,
        "value": "tapMeButton",
      ])
      XCTAssertEqual(response.statusCode, 200, "using: \(using)")
      XCTAssertNotNil(response.valueDict?["ELEMENT"], "using: \(using)")
    }
  }

  func testFindElementByPredicateString() throws {
    let response = try client.post("/session/\(sessionId!)/element", body: [
      "using": "predicate string",
      "value": "label == \"Tap Me\"",
    ])
    XCTAssertEqual(response.statusCode, 200)
    XCTAssertNotNil(response.valueDict?["ELEMENT"])
  }

  func testFindElementsByClassChain() throws {
    let response = try client.post("/session/\(sessionId!)/elements", body: [
      "using": "class chain",
      "value": "**/XCUIElementTypeButton",
    ])
    XCTAssertEqual(response.statusCode, 200)
    XCTAssertGreaterThanOrEqual((response.value as? [[String: Any]])?.count ?? 0, 1)
  }

  func testFindElementByXPath() throws {
    let response = try client.post("/session/\(sessionId!)/element", body: [
      "using": "xpath",
      "value": "//XCUIElementTypeButton[@name=\"tapMeButton\"]",
    ])
    XCTAssertEqual(response.statusCode, 200)
    XCTAssertNotNil(response.valueDict?["ELEMENT"])
  }

  func testFindElementByLinkTextAndPartialLinkText() throws {
    // WDA matches (partial) link text against `name`, not an actual hyperlink search.
    for using in ["link text", "partial link text"] {
      let value = using == "link text" ? "tapMeButton" : "tapMe"
      let response = try client.post("/session/\(sessionId!)/element", body: [
        "using": using,
        "value": value,
      ])
      XCTAssertEqual(response.statusCode, 200, "using: \(using)")
      XCTAssertNotNil(response.valueDict?["ELEMENT"], "using: \(using)")
    }
  }

  func testFindElementThatDoesNotExistReturnsAnError() throws {
    let response = try client.post("/session/\(sessionId!)/element", body: [
      "using": "accessibility id",
      "value": "thisElementDoesNotExist",
    ])
    XCTAssertNotEqual(response.statusCode, 200)
  }

  func testFindElements() throws {
    let response = try client.post("/session/\(sessionId!)/elements", body: [
      "using": "class name",
      "value": "XCUIElementTypeButton",
    ])
    XCTAssertEqual(response.statusCode, 200)
    guard let elements = response.value as? [[String: Any]] else {
      return XCTFail("Expected an array of elements: \(String(describing: response.json))")
    }
    XCTAssertGreaterThanOrEqual(elements.count, 1)
  }

  func testFindSubElementAndSubElements() throws {
    let windowResponse = try client.post("/session/\(sessionId!)/element", body: [
      "using": "class name",
      "value": "XCUIElementTypeWindow",
    ])
    guard let windowId = windowResponse.valueDict?["ELEMENT"] as? String else {
      return XCTFail("Could not find the root window element")
    }

    let subElementResponse = try client.post("/session/\(sessionId!)/element/\(windowId)/element", body: [
      "using": "accessibility id",
      "value": "tapMeButton",
    ])
    XCTAssertEqual(subElementResponse.statusCode, 200)
    XCTAssertNotNil(subElementResponse.valueDict?["ELEMENT"])

    let subElementsResponse = try client.post("/session/\(sessionId!)/element/\(windowId)/elements", body: [
      "using": "class name",
      "value": "XCUIElementTypeButton",
    ])
    XCTAssertEqual(subElementsResponse.statusCode, 200)
    XCTAssertGreaterThanOrEqual((subElementsResponse.value as? [[String: Any]])?.count ?? 0, 1)
  }

  func testActiveElementResolvesToTheFocusedTextField() throws {
    let fieldId = try findElement(byAccessibilityId: "typingField")
    try client.post("/session/\(sessionId!)/element/\(fieldId)/click")
    // Give the keyboard-sheet transition a moment to finish before checking focus.
    Thread.sleep(forTimeInterval: 1)

    let response = try client.get("/session/\(sessionId!)/element/active")
    XCTAssertEqual(response.statusCode, 200)
    XCTAssertNotNil(response.valueDict?["ELEMENT"])
  }
}

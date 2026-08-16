/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import XCTest

/// Covers the app lifecycle routes (launch/activate/terminate/state/list). Unlike
/// /wda/homescreen or /wda/lock, these only ever target IntegrationApp_watchOS, so they're
/// safe to run repeatedly without disrupting shared simulator state.
final class WDAAppLifecycleIntegrationTests: WDAWatchIntegrationTestCase {
  // XCUIApplicationState raw values: NotRunning = 1, RunningForeground = 4.
  private static let notRunningState = 1
  private static let runningForegroundState = 4

  func testAppsListIncludesTheAppUnderTest() throws {
    let response = try client.get("/session/\(sessionId!)/wda/apps/list")
    XCTAssertEqual(response.statusCode, 200)
    guard let apps = response.value as? [[String: Any]] else {
      return XCTFail("Expected an array of active apps: \(String(describing: response.json))")
    }
    XCTAssertTrue(apps.contains { $0["bundleId"] as? String == Self.integrationAppBundleId })
  }

  func testTerminateThenRelaunchLifecycle() throws {
    let bundleId = Self.integrationAppBundleId

    let terminateResponse = try client.post("/session/\(sessionId!)/wda/apps/terminate", body: ["bundleId": bundleId])
    XCTAssertEqual(terminateResponse.statusCode, 200)
    XCTAssertEqual(terminateResponse.value as? Bool, true)

    let stateAfterTerminate = try client.post("/session/\(sessionId!)/wda/apps/state", body: ["bundleId": bundleId])
    XCTAssertEqual(stateAfterTerminate.value as? Int, Self.notRunningState)

    let launchResponse = try client.post("/session/\(sessionId!)/wda/apps/launch", body: ["bundleId": bundleId])
    XCTAssertEqual(launchResponse.statusCode, 200)
    Thread.sleep(forTimeInterval: 1)

    let stateAfterLaunch = try client.post("/session/\(sessionId!)/wda/apps/state", body: ["bundleId": bundleId])
    XCTAssertEqual(stateAfterLaunch.value as? Int, Self.runningForegroundState)

    // The app relaunched fresh, so its accessibility tree should be back too.
    XCTAssertNoThrow(try findElement(byAccessibilityId: "tapMeButton"))
  }

  func testActivateBringsTheAppToTheForeground() throws {
    let bundleId = Self.integrationAppBundleId
    let activateResponse = try client.post("/session/\(sessionId!)/wda/apps/activate", body: ["bundleId": bundleId])
    XCTAssertEqual(activateResponse.statusCode, 200)

    let stateResponse = try client.post("/session/\(sessionId!)/wda/apps/state", body: ["bundleId": bundleId])
    XCTAssertEqual(stateResponse.value as? Int, Self.runningForegroundState)
  }
}

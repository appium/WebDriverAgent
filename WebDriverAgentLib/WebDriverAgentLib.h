/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <UIKit/UIKit.h>

//! Project version number for WebDriverAgentLib_.
FOUNDATION_EXPORT double WebDriverAgentLib_VersionNumber;

//! Project version string for WebDriverAgentLib_.
FOUNDATION_EXPORT const unsigned char WebDriverAgentLib_VersionString[];

#import <WebDriverAgentLib/CDStructures.h>
#import <WebDriverAgentLib/FBAlert.h>
#import <WebDriverAgentLib/FBAlertViewCommands.h>
#import <WebDriverAgentLib/FBCapabilities.h>
#import <WebDriverAgentLib/FBCommandHandler.h>
#import <WebDriverAgentLib/FBCommandStatus.h>
#import <WebDriverAgentLib/FBConfiguration.h>
#import <WebDriverAgentLib/FBCustomCommands.h>
#import <WebDriverAgentLib/FBDebugCommands.h>
#import <WebDriverAgentLib/FBDebugLogDelegateDecorator.h>
#import <WebDriverAgentLib/FBElement.h>
#import <WebDriverAgentLib/FBElementCache.h>
#import <WebDriverAgentLib/FBElementCommands.h>
#import <WebDriverAgentLib/FBElementTypeTransformer.h>
#import <WebDriverAgentLib/FBErrorBuilder.h>
#import <WebDriverAgentLib/FBExceptions.h>
#import <WebDriverAgentLib/FBExceptionHandler.h>
#import <WebDriverAgentLib/FBFindElementCommands.h>
#import <WebDriverAgentLib/FBHTTPStatusCodes.h>
#import <WebDriverAgentLib/FBFailureProofTestCase.h>
#import <WebDriverAgentLib/FBKeyboard.h>
#import <WebDriverAgentLib/FBLogger.h>
#import <WebDriverAgentLib/FBMacros.h>
#import <WebDriverAgentLib/FBMathUtils.h>
#import <WebDriverAgentLib/FBOrientationCommands.h>
#import <WebDriverAgentLib/FBProtocolHelpers.h>
#import <WebDriverAgentLib/FBResponseJSONPayload.h>
#import <WebDriverAgentLib/FBResponsePayload.h>
#import <WebDriverAgentLib/FBRoute.h>
#import <WebDriverAgentLib/FBRouteRequest.h>
#import <WebDriverAgentLib/FBRunLoopSpinner.h>
#import <WebDriverAgentLib/FBRuntimeUtils.h>
#import <WebDriverAgentLib/FBScreenshotCommands.h>
#import <WebDriverAgentLib/FBSession.h>
#import <WebDriverAgentLib/FBSessionCommands.h>
#import <WebDriverAgentLib/FBSettings.h>
#import <WebDriverAgentLib/FBTouchActionCommands.h>
#import <WebDriverAgentLib/FBTouchIDCommands.h>
#import <WebDriverAgentLib/FBVideoCommands.h>
#import <WebDriverAgentLib/FBWebServer.h>
#import <WebDriverAgentLib/FBXCElementSnapshot.h>
#import <WebDriverAgentLib/FBXCElementSnapshotWrapper.h>
#import <WebDriverAgentLib/FBXCodeCompatibility.h>
#import <WebDriverAgentLib/FBXPath.h>
#import <WebDriverAgentLib/WebDriverAgentLib.h>
#import <WebDriverAgentLib/XCDebugLogDelegate-Protocol.h>
#import <WebDriverAgentLib/XCPointerEvent.h>
#import <WebDriverAgentLib/XCTestCase.h>
#import <WebDriverAgentLib/XCTIssue+FBPatcher.h>
#import <WebDriverAgentLib/XCUIApplication.h>
#import <WebDriverAgentLib/XCUIApplication+FBHelpers.h>
#import <WebDriverAgentLib/XCUIApplication+FBQuiescence.h>
#import <WebDriverAgentLib/XCUIApplicationProcessDelay.h>
#import <WebDriverAgentLib/XCUIDevice+FBHelpers.h>
#import <WebDriverAgentLib/XCUIDevice+FBHealthCheck.h>
#import <WebDriverAgentLib/XCUIDevice+FBRotation.h>
#import <WebDriverAgentLib/XCUIElement.h>
#import <WebDriverAgentLib/XCUIElement+FBAccessibility.h>
#import <WebDriverAgentLib/XCUIElement+FBFind.h>
#import <WebDriverAgentLib/XCUIElement+FBIsVisible.h>
#import <WebDriverAgentLib/XCUIElement+FBScrolling.h>
#import <WebDriverAgentLib/XCUIElement+FBForceTouch.h>
#import <WebDriverAgentLib/XCUIElement+FBUtilities.h>
#import <WebDriverAgentLib/XCUIElement+FBWebDriverAttributes.h>
#import <WebDriverAgentLib/XCTIssue+FBPatcher.h>

// QAWolf code
#import <WebDriverAgentLib/ExecuteWDACommand.h>
#import <WebDriverAgentLib/HandleWDACommandException.h>

/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

// Exposes the WebDriverAgentLib_watchOS categories these tests call directly, in-process,
// instead of going through the HTTP server.

#import "XCUIElement+FBFind.h"
#import "XCUIElement+FBClassChain.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "XCUIElement+FBTyping.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIDevice+FBHelpers.h"
#import "FBAlert.h"
#import "FBElement.h"
#import "FBMjpegServer.h"
#import "FBTCPSocket.h"

/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

/*! Exception used to notify about missing session */
extern NSString *const FBSessionDoesNotExistException;

/*! Exception used to notify about session creation issues */
extern NSString *const FBSessionCreationException;

/*! Exception used to notify about application deadlock */
extern NSString *const FBApplicationDeadlockDetectedException;

/*! Exception used to notify about unknown attribute */
extern NSString *const FBElementAttributeUnknownException;

/*! Exception used to notify about invalid argument */
extern NSString *const FBInvalidArgumentException;

/*! Exception used to notify about invisibility of an element while trying to interact with it */
extern NSString *const FBElementNotVisibleException;

/*! Exception used to notify about a timeout */
extern NSString *const FBTimeoutException;

/**
 The exception happends if the cached element does not exist in DOM anymore
 */
extern NSString *const FBStaleElementException;

/**
 The exception happends if the provided XPath expession cannot be compiled because of a syntax error
 */
extern NSString *const FBInvalidXPathException;
/**
 The exception happends if any internal error is triggered during XPath matching procedure
 */
extern NSString *const FBXPathQueryEvaluationException;

/*! Exception used to notify about invalid class chain query */
extern NSString *const FBClassChainQueryParseException;

/*! Exception used to notify about application crash */
extern NSString *const FBApplicationCrashedException;

/*! Exception used to notify about the application is not installed  */
extern NSString *const FBApplicationMissingException;

/*! Exception used to notify about WDA incompatibility with the current platform version */
extern NSString *const FBIncompatibleWdaException;

NS_ASSUME_NONNULL_END

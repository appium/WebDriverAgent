/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

@class FBApplication;
@class FBElementCache;

NS_ASSUME_NONNULL_BEGIN

/**
 Class that represents testing session
 */
@interface FBSession : NSObject

/*! Application tested during that session */
@property (nonatomic, strong, readonly) FBApplication *activeApplication;

/*! Session's identifier */
@property (nonatomic, copy, readonly) NSString *identifier;

/*! Element cache related to that session */
@property (nonatomic, strong, readonly) FBElementCache *elementCache;

/*! The identifier of the active application */
@property (nonatomic, copy) NSString *defaultActiveApplication;

/*! The action to apply to unexpected alerts. Either "accept"/"dismiss" or nil/empty string (by default) to do nothing */
@property (nonatomic, nullable) NSString *defaultAlertAction;

/*! Whether to use the native caching strategy for elements or the custom one: https://discuss.appium.io/t/elements-state-coming-from-xpath-vs-ios-predicate-string/34016 */
@property (nonatomic) BOOL useNativeCachingStrategy;

/*! Keeps cached visibility values for the current snapshots tree */
@property (nonatomic, readonly) NSMutableDictionary<NSNumber *, NSMutableDictionary<NSString *, NSNumber *> *> *elementsVisibilityCache;

+ (nullable instancetype)activeSession;

/**
 Fetches session for given identifier.
 If identifier doesn't match activeSession identifier, will return nil.

 @param identifier Identifier for searched session
 @return session. Can return nil if session does not exists
 */
+ (nullable instancetype)sessionWithIdentifier:(NSString *)identifier;

/**
 Creates and saves new session for application

 @param application The application that we want to create session for
 @return new session
 */
+ (instancetype)initWithApplication:(nullable FBApplication *)application;

/**
 Creates and saves new session for application with default alert handling behaviour

 @param application The application that we want to create session for
 @param defaultAlertAction The default reaction to on-screen alert. Either 'accept' or 'dismiss'
 @return new session
 */
+ (instancetype)initWithApplication:(nullable FBApplication *)application defaultAlertAction:(NSString *)defaultAlertAction;

/**
 Kills application associated with that session and removes session
 */
- (void)kill;

/**
 Launch an application with given bundle identifier in scope of current session.
 !This method is only available since Xcode9 SDK

 @param bundleIdentifier Valid bundle identifier of the application to be launched
 @param shouldWaitForQuiescence whether to wait for quiescence on application startup
 @param arguments The optional array of application command line arguments. The arguments are going to be applied if the application was not running before.
 @param environment The optional dictionary of environment variables for the application, which is going to be executed. The environment variables are going to be applied if the application was not running before.
 @return The application instance
 @throws FBApplicationMethodNotSupportedException if the method is not supported with the current XCTest SDK
 */
- (FBApplication *)launchApplicationWithBundleId:(NSString *)bundleIdentifier
                         shouldWaitForQuiescence:(nullable NSNumber *)shouldWaitForQuiescence
                                       arguments:(nullable NSArray<NSString *> *)arguments
                                     environment:(nullable NSDictionary <NSString *, NSString *> *)environment;

/**
 Activate an application with given bundle identifier in scope of current session.
 !This method is only available since Xcode9 SDK

 @param bundleIdentifier Valid bundle identifier of the application to be activated
 @return The application instance
 @throws FBApplicationMethodNotSupportedException if the method is not supported with the current XCTest SDK
 */
- (FBApplication *)activateApplicationWithBundleId:(NSString *)bundleIdentifier;

/**
 Terminate an application with the given bundle id. The application should be previously
 executed by launchApplicationWithBundleId method or passed to the init method.

 @param bundleIdentifier Valid bundle identifier of the application to be terminated
 @return Either YES if the app has been successfully terminated or NO if it was not running
 */
- (BOOL)terminateApplicationWithBundleId:(NSString *)bundleIdentifier;

/**
 Get the state of the particular application in scope of the current session.
 !This method is only returning reliable results since Xcode9 SDK

 @param bundleIdentifier Valid bundle identifier of the application to get the state from
 @return Application state as integer number. See
         https://developer.apple.com/documentation/xctest/xcuiapplicationstate?language=objc
         for more details on possible enum values
 */
- (NSUInteger)applicationStateWithBundleId:(NSString *)bundleIdentifier;

@end

NS_ASSUME_NONNULL_END

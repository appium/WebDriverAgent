/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSPredicate (FBFormat)

/**
 Method used to normalize/verify NSPredicate expressions before passing them to WDA.
 Only expressions of NSKeyPathExpressionType are going to be verified.
 Allowed property names are only these declared in FBElement protocol (property names are received in runtime)
 and their shortcuts (without 'wd' prefix). All other property names are considered as unknown.
 
 @param input predicate object received from user input
 @return formatted predicate
 @throw FBUnknownPredicateKeyException in case the given property name is not declared in FBElement protocol
 */
+ (instancetype)fb_formatSearchPredicate:(NSPredicate *)input;

/**
 Creates a block predicate expression, which properly evalluates the given raw predicate agains
 xctest hierarchy. Vanilla string predicates don't work on this hierachy because "raw" snapshots
 don't have any of the custom properties declared in FBElement protocol.
 `fb_formatSearchPredicate` is called automtically on the original predicate before
 making it to a block.
 
 @param input predicate object received from user input
 @return formatted predicate
 @throw FBUnknownPredicateKeyException in case the given property name is not declared in FBElement protocol
 */
+ (instancetype)fb_snapshotBlockPredicateWithPredicate:(NSPredicate *)input;

@end

NS_ASSUME_NONNULL_END

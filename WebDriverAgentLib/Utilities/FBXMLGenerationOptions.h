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

@interface FBXMLGenerationOptions : NSObject

/**
 XML buidling scope. Passing nil means the XML should be built in the default scope,
 i.e no changes to the original tree structore. If the scope is provided then the resulting
 XML tree will be put under the root, which name is equal to the given scope value.
 */
@property (nonatomic, nullable) NSString *scope;
/**
 The list of attribute names to exclude from the resulting document.
 Passing nil means all the available attributes should be included
 */
@property (nonatomic, nullable) NSArray<NSString *> *excludedAttributes;

/**
 Allows to provide XML scope.

 @param scope See the property description above
 @return self instance for chaining
 */
- (FBXMLGenerationOptions *)withScope:(nullable NSString *)scope;

/**
 Allows to provide a list of excluded XML attributes.

 @param excludedAttributes See the property description above
 @return self instance for chaining
 */
- (FBXMLGenerationOptions *)withExcludedAttributes:(nullable NSArray<NSString *> *)excludedAttributes;

@end

NS_ASSUME_NONNULL_END

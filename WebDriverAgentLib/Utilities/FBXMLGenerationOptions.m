/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "FBXMLGenerationOptions.h"

@implementation FBXMLGenerationOptions

- (FBXMLGenerationOptions *)withScope:(NSString *)scope
{
  self.scope = scope;
  return self;
}

- (FBXMLGenerationOptions *)withExcludedAttributes:(NSArray<NSString *> *)excludedAttributes
{
  self.excludedAttributes = excludedAttributes;
  return self;
}

@end

/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCAXClient_iOS+FBSnapshotReqParams.h"

#import <objc/runtime.h>

#import "FBReflectionUtils.h"

NSString *const FBSnapshotMaxDepthKey = @"maxDepth";
NSString *const FBSnapshotHonorModalViewsKey = @"snapshotKeyHonorModalViews";

static id (*original_defaultParameters)(id, SEL);
static NSMutableDictionary *customRequestParameters;

void FBSetCustomParameterForElementSnapshot (NSString *name, id value)
{
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    customRequestParameters = [NSMutableDictionary new];
  });
  customRequestParameters[name] = value;
}

id FBGetCustomParameterForElementSnapshot (NSString *name)
{
  return customRequestParameters[name];
}

static id swizzleDefaultParameters(id self, SEL _cmd)
{
  NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:original_defaultParameters(self, _cmd)];
  if (nil != customRequestParameters && customRequestParameters.count > 0) {
    [result addEntriesFromDictionary:customRequestParameters];
  }
  return result.copy;
}

@implementation XCAXClient_iOS (FBSnapshotReqParams)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-load-method"

+ (void)load
{
  Method original_defaultParametersMethod = class_getInstanceMethod(self.class, @selector(defaultParameters));
  IMP swizzledImp = (IMP)swizzleDefaultParameters;
  original_defaultParameters = (id (*)(id, SEL)) method_setImplementation(original_defaultParametersMethod, swizzledImp);
}

#pragma clang diagnostic pop

@end

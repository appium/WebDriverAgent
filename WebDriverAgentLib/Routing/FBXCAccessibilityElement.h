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

@protocol FBXCAccessibilityElement <NSObject>

@property(readonly) id payload; // @synthesize payload=_payload;
@property(readonly) int processIdentifier; // @synthesize processIdentifier=_processIdentifier;
@property(readonly) const struct __AXUIElement *AXUIElement; // @synthesize AXUIElement=_axElement;
@property(readonly, getter=isNative) BOOL native;

+ (id)elementWithAXUIElement:(struct __AXUIElement *)arg1;
+ (id)elementWithProcessIdentifier:(int)arg1;
+ (id)deviceElement;
+ (id)mockElementWithProcessIdentifier:(int)arg1 payload:(id)arg2;
+ (id)mockElementWithProcessIdentifier:(int)arg1;

- (id)initWithMockProcessIdentifier:(int)arg1 payload:(id)arg2;
- (id)initWithAXUIElement:(struct __AXUIElement *)arg1;
- (id)init;

@end

BOOL FBIsAXElementEqualToOther(id<FBXCAccessibilityElement> first, id<FBXCAccessibilityElement> second);

NS_ASSUME_NONNULL_END

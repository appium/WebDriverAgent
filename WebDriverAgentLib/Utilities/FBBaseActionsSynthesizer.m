/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBBaseActionsSynthesizer.h"

#import "FBErrorBuilder.h"
#import "FBLogger.h"
#import "FBMacros.h"
#import "FBMathUtils.h"
#import "FBXCElementSnapshotWrapper+Helpers.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIElement.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBCaching.h"
#import "XCPointerEventPath.h"
#import "XCSynthesizedEventRecord.h"
#import "XCUIElement+FBUtilities.h"

#if !TARGET_OS_TV
@implementation FBBaseActionItem

+ (NSString *)actionName
{
  @throw [[FBErrorBuilder.builder withDescription:@"Override this method in subclasses"] build];
  return nil;
}

- (NSArray<XCPointerEventPath *> *)addToEventPath:(XCPointerEventPath *)eventPath
                                         allItems:(NSArray *)allItems
                                 currentItemIndex:(NSUInteger)currentItemIndex
                                            error:(NSError **)error
{
  @throw [[FBErrorBuilder.builder withDescription:@"Override this method in subclasses"] build];
  return nil;
}

@end

@implementation FBBaseGestureItem

- (nullable XCUICoordinate *)hitpointWithElement:(nullable XCUIElement *)element
                                  positionOffset:(nullable NSValue *)positionOffset
                                           error:(NSError **)error
{
  if (nil == element) {
    CGVector offset = CGVectorMake(positionOffset.CGPointValue.x, positionOffset.CGPointValue.y);
    // Only absolute offset is defined
    return [[self.application coordinateWithNormalizedOffset:CGVectorMake(0, 0)] coordinateWithOffset:offset];
  }

  // The offset relative to the element is defined
  if (nil == positionOffset) {
    if (element.hittable) {
      // short circuit element hitpoint
      return element.hitPointCoordinate;
    }
    [FBLogger logFmt:@"Will use the frame of '%@' for hit point calculation instead", element.debugDescription];
  }
  if (CGRectIsEmpty(element.frame)) {
    [FBLogger log:self.application.fb_descriptionRepresentation];
    NSString *description = [NSString stringWithFormat:@"The element '%@' is not visible on the screen and thus is not interactable",
                             element.description];
    if (error) {
      *error = [[FBErrorBuilder.builder withDescription:description] build];
    }
    return nil;
  }
  if (nil == positionOffset) {
    return [element coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.5)];
  }

  CGVector offset = CGVectorMake(positionOffset.CGPointValue.x, positionOffset.CGPointValue.y);
  // TODO: Shall we throw an exception if hitPoint is out of the element frame?
  return [[element coordinateWithNormalizedOffset:CGVectorMake(0, 0)] coordinateWithOffset:offset];
}

@end


@implementation FBBaseActionItemsChain

- (instancetype)init
{
  self = [super init];
  if (self) {
    _items = [NSMutableArray array];
    _durationOffset = 0.0;
  }
  return self;
}

- (void)addItem:(FBBaseActionItem *)item __attribute__((noreturn))
{
  @throw [[FBErrorBuilder.builder withDescription:@"Override this method in subclasses"] build];
}

- (nullable NSArray<XCPointerEventPath *> *)asEventPathsWithError:(NSError **)error
{
  if (0 == self.items.count) {
    if (error) {
      *error = [[FBErrorBuilder.builder withDescription:@"Action items list cannot be empty"] build];
    }
    return nil;
  }
  
  NSMutableArray<XCPointerEventPath *> *result = [NSMutableArray array];
  XCPointerEventPath *previousEventPath = nil;
  XCPointerEventPath *currentEventPath = nil;
  NSUInteger index = 0;
  for (FBBaseActionItem *item in self.items.copy) {
    NSArray<XCPointerEventPath *> *currentEventPaths = [item addToEventPath:currentEventPath
                                                                   allItems:self.items.copy
                                                           currentItemIndex:index++
                                                                      error:error];
    if (currentEventPaths == nil) {
      return nil;
    }

    currentEventPath = currentEventPaths.lastObject;
    if (nil == currentEventPath) {
      currentEventPath = previousEventPath;
    } else if (currentEventPath != previousEventPath) {
      [result addObjectsFromArray:currentEventPaths];
      previousEventPath = currentEventPath;
    }
  }
  return result.copy;
}

@end


@implementation FBBaseActionsSynthesizer

- (instancetype)initWithActions:(NSArray *)actions
                 forApplication:(XCUIApplication *)application
                   elementCache:(nullable FBElementCache *)elementCache
                          error:(NSError **)error
{
  self = [super init];
  if (self) {
    if ((nil == actions || 0 == actions.count) && error) {
      *error = [[FBErrorBuilder.builder withDescription:@"Actions list cannot be empty"] build];
      return nil;
    }
    _actions = actions;
    _application = application;
    _elementCache = elementCache;
  }
  return self;
}

- (nullable XCSynthesizedEventRecord *)synthesizeWithError:(NSError **)error
{
  @throw [[FBErrorBuilder.builder withDescription:@"Override synthesizeWithError method in subclasses"] build];
  return nil;
}

@end
#endif

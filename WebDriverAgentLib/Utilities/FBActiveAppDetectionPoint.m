/**
* Copyright (c) 2015-present, Facebook, Inc.
* All rights reserved.
*
* This source code is licensed under the BSD-style license found in the
* LICENSE file in the root directory of this source tree. An additional grant
* of patent rights can be found in the PATENTS file in the same directory.
*/

#import "FBActiveAppDetectionPoint.h"

#import "FBErrorBuilder.h"
#import "FBLogger.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCTestManager_ManagerInterface-Protocol.h"

@implementation FBActiveAppDetectionPoint

- (instancetype)init {
  if ((self = [super init])) {
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    // Consider the element, which is located close to the top left corner of the screen the on-screen one.
    CGFloat pointDistance = MIN(screenSize.width, screenSize.height) * 0.2;
    _coordinates = CGPointMake(pointDistance, pointDistance);
  }
  return self;
}

+ (instancetype)sharedInstance
{
  static FBActiveAppDetectionPoint *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[self alloc] init];
  });
  return instance;
}

+ (XCAccessibilityElement *)axElementWithPoint:(CGPoint)point
{
  __block XCAccessibilityElement *onScreenElement = nil;
  id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [proxy _XCT_requestElementAtPoint:point
                              reply:^(XCAccessibilityElement *element, NSError *error) {
                                if (nil == error) {
                                  onScreenElement = element;
                                } else {
                                  [FBLogger logFmt:@"Cannot request the screen point at %@: %@", [NSValue valueWithCGPoint:point], error.description];
                                }
                                dispatch_semaphore_signal(sem);
                              }];
  dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)));
  return onScreenElement;
}

- (XCAccessibilityElement *)axElement
{
  return [self.class axElementWithPoint:self.coordinates];
}

- (BOOL)setCoordinatesWithString:(NSString *)coordinatesStr error:(NSError **)error
{
  NSArray<NSString *> *screenPointCoords = [coordinatesStr componentsSeparatedByString:@","];
  if (screenPointCoords.count != 2) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"The screen point coordinates should be separated by a single comma character. Got '%@' instead", coordinatesStr]
            buildError:error];
  }
  NSString *strX = [screenPointCoords.firstObject stringByTrimmingCharactersInSet:
                    NSCharacterSet.whitespaceAndNewlineCharacterSet];
  NSString *strY = [screenPointCoords.lastObject stringByTrimmingCharactersInSet:
                    NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (0 == strX.length || 0 == strY.length) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"Both screen point coordinates should be valid numbers. Got '%@' instead", coordinatesStr]
            buildError:error];
  }
  self.coordinates = CGPointMake(strX.doubleValue, strY.doubleValue);
  return YES;
}

- (NSString *)stringCoordinates
{
  return [NSString stringWithFormat:@"%.2f,%.2f", self.coordinates.x, self.coordinates.y];
}

@end

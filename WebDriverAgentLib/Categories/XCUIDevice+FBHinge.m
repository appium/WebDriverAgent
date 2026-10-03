/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "XCUIDevice+FBHinge.h"

#import <dlfcn.h>
#import <math.h>
#import <mach/mach_time.h>

#import "FBErrorBuilder.h"

#if !TARGET_OS_TV && !TARGET_OS_WATCH
typedef CFDataRef (*FBIOCFSerialize)(CFTypeRef object, CFOptionFlags options);
typedef CFTypeRef (*FBIOHIDEventCreateVendorDefinedEvent)(CFAllocatorRef allocator,
                                                       uint64_t timestamp,
                                                       uint32_t usagePage,
                                                       uint32_t usage,
                                                       uint32_t version,
                                                       uint8_t *data,
                                                       CFIndex length,
                                                       uint32_t options);
typedef CFTypeRef (*FBIOHIDEventSystemClientCreate)(CFAllocatorRef allocator);
typedef void (*FBIOHIDEventSystemClientDispatchEvent)(CFTypeRef client, CFTypeRef event);

@protocol FBAngle <NSObject>
- (BOOL)isAngleValid;
- (float)angleDegrees;
@end

@protocol FBAngleManager <NSObject>
+ (instancetype)new;
+ (BOOL)isAvailable;
- (void)startAngleUpdatesToQueue:(NSOperationQueue *)queue handler:(void (^)(id<FBAngle>))handler;
- (void)stopAngleUpdates;
@end

static Class<FBAngleManager> FBAngleManagerClass(void)
{
  static Class<FBAngleManager> angleManagerClass;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if (NULL != dlopen("/System/Library/Frameworks/CoreMotion.framework/CoreMotion", RTLD_LAZY)) {
      angleManagerClass = NSClassFromString(@"CMAngleManager");
    }
  });
  return angleManagerClass;
}
#endif

@implementation XCUIDevice (FBHinge)

- (BOOL)fb_supportsSimulatedHingeAngle
{
#if !TARGET_OS_TV && !TARGET_OS_WATCH
  Class<FBAngleManager> angleManagerClass = FBAngleManagerClass();
  if (![angleManagerClass respondsToSelector:@selector(isAvailable)]) {
    return NO;
  }
  // Hinge availability permits an injection attempt; it does not guarantee
  // that the device accepts the vendor event. Physical devices are unverified.
  return [angleManagerClass isAvailable];
#else
  return NO;
#endif
}

- (nullable NSNumber *)fb_getSimulatedHingeAngle:(NSError **)error
{
  if (!self.fb_supportsSimulatedHingeAngle) {
    [[FBErrorBuilder.builder withDescription:@"The device does not report an available hinge"] buildError:error];
    return nil;
  }
#if !TARGET_OS_TV && !TARGET_OS_WATCH
  id<FBAngleManager> manager = [FBAngleManagerClass() new];
  if (![manager respondsToSelector:@selector(startAngleUpdatesToQueue:handler:)]
      || ![manager respondsToSelector:@selector(stopAngleUpdates)]) {
    [[FBErrorBuilder.builder withDescription:@"The runtime does not provide the required hinge angle reading APIs"] buildError:error];
    return nil;
  }
  NSOperationQueue *queue = [NSOperationQueue new];
  queue.maxConcurrentOperationCount = 1;
  NSCondition *condition = [NSCondition new];
  __block NSNumber *reading = nil;
  NSNumber *result;
  @try {
    [manager startAngleUpdatesToQueue:queue handler:^(id<FBAngle> angle) {
      if (![angle respondsToSelector:@selector(isAngleValid)]
          || ![angle respondsToSelector:@selector(angleDegrees)] || !angle.isAngleValid) {
        return;
      }
      float degrees = angle.angleDegrees;
      if (!isfinite(degrees)) {
        return;
      }
      [condition lock];
      if (nil == reading) {
        reading = @(degrees);
        [condition signal];
      }
      [condition unlock];
    }];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
    [condition lock];
    while (nil == reading) {
      if (![condition waitUntilDate:deadline]) {
        break;
      }
    }
    result = reading;
    [condition unlock];
  } @finally {
    [manager stopAngleUpdates];
  }
  if (nil == result) {
    [[FBErrorBuilder.builder withDescription:@"Timed out after 5 seconds waiting for a valid hinge angle"] buildError:error];
  }
  return result;
#else
  return nil;
#endif
}

- (BOOL)fb_setSimulatedHingeAngle:(double)angle error:(NSError **)error
{
  if (!isfinite(angle) || angle < 0 || angle > 180) {
    return [[FBErrorBuilder.builder withDescription:@"Hinge angle must be a finite number between 0 and 180 degrees"] buildError:error];
  }
  if (!self.fb_supportsSimulatedHingeAngle) {
    return [[FBErrorBuilder.builder withDescription:@"The device does not report an available hinge"] buildError:error];
  }
#if !TARGET_OS_TV && !TARGET_OS_WATCH
  static FBIOCFSerialize serialize;
  static FBIOHIDEventCreateVendorDefinedEvent createEvent;
  static FBIOHIDEventSystemClientCreate createClient;
  static FBIOHIDEventSystemClientDispatchEvent dispatchEvent;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (NULL != handle) {
      serialize = (FBIOCFSerialize)dlsym(handle, "IOCFSerialize");
      createEvent = (FBIOHIDEventCreateVendorDefinedEvent)dlsym(handle, "IOHIDEventCreateVendorDefinedEvent");
      createClient = (FBIOHIDEventSystemClientCreate)dlsym(handle, "IOHIDEventSystemClientCreate");
      dispatchEvent = (FBIOHIDEventSystemClientDispatchEvent)dlsym(handle, "IOHIDEventSystemClientDispatchEvent");
    }
  });
  if (NULL == serialize || NULL == createEvent || NULL == createClient || NULL == dispatchEvent) {
    return [[FBErrorBuilder.builder withDescription:@"The runtime does not provide the required IOKit HID APIs"] buildError:error];
  }
  // Matches Device Hub's hinge-slider-control payload (Xcode 27.1). It is an
  // IOCF binary serialization, not an NSPropertyListSerialization binary plist.
  NSDictionary *payload = @{
    @"provider": @"com.apple.Virtualization.VirtualMachines",
    @"source": @"hinge-slider-control",
    @"type": @"range",
    @"value": @(angle),
  };
  CFDataRef data = serialize((__bridge CFTypeRef)payload, 1);
  if (NULL == data) {
    return [[FBErrorBuilder.builder withDescription:@"Cannot serialize the simulated hinge event"] buildError:error];
  }
  CFTypeRef event = createEvent(kCFAllocatorDefault, mach_absolute_time(), 0xff61, 0x5b, 0,
                               (uint8_t *)CFDataGetBytePtr(data), CFDataGetLength(data), 0);
  CFRelease(data);
  CFTypeRef client = createClient(kCFAllocatorDefault);
  BOOL canDispatch = NULL != event && NULL != client;
  if (canDispatch) {
    dispatchEvent(client, event);
  }
  if (NULL != event) {
    CFRelease(event);
  }
  if (NULL != client) {
    CFRelease(client);
  }
  return canDispatch || [[FBErrorBuilder.builder withDescription:@"Cannot create the simulated hinge HID event or client"] buildError:error];
#else
  return NO;
#endif
}

@end

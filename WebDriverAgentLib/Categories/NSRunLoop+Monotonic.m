#import "NSRunLoop+Monotonic.h"
#import <QuartzCore/QuartzCore.h>

@implementation NSRunLoop (Monotonic)

/**
 * Runs the current run loop for a specified monotonic interval (in seconds),
 * using CACurrentMediaTime for time measurement. This method is not affected by system time changes.
 *
 * @param seconds The duration to run the run loop, measured in monotonic time.
 */
- (void)runForMonotonicInterval:(NSTimeInterval)seconds {
    CFTimeInterval end = CACurrentMediaTime() + seconds;
    while (CACurrentMediaTime() < end) {
        [self runMode:NSRunLoopCommonModes beforeDate:[NSDate distantFuture]];
    }
}

@end

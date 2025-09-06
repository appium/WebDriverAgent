#import "NSRunLoop+Monotonic.h"
#import <QuartzCore/QuartzCore.h>

@implementation NSRunLoop (Monotonic)

- (void)runForMonotonicInterval:(NSTimeInterval)seconds {
    CFTimeInterval end = CACurrentMediaTime() + seconds;
    while (CACurrentMediaTime() < end) {
        [self runMode:NSRunLoopCommonModes beforeDate:[NSDate distantFuture]];
    }
}

@end

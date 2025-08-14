#import "NSRunLoop+Monotonic.h"
#import <QuartzCore/QuartzCore.h> // 为了用 CACurrentMediaTime()

@implementation NSRunLoop (Monotonic)

- (void)runForMonotonicInterval:(NSTimeInterval)seconds {
    CFTimeInterval end = CACurrentMediaTime() + seconds;
    while (CACurrentMediaTime() < end) {
        [self runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
}

@end
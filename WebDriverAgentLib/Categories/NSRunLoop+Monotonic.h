#import <Foundation/Foundation.h>

@interface NSRunLoop (Monotonic)
/**
 Runs the current run loop in the default mode for the specified monotonic time interval.

 This method uses a monotonic clock to ensure the interval is not affected
 by changes to the system clock. The run loop will repeatedly process events
 until the given number of seconds has elapsed.

 @param seconds The duration, in seconds, to run the run loop.
 */
- (void)runForMonotonicInterval:(NSTimeInterval)seconds;
@end
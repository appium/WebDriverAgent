#import <Foundation/Foundation.h>

@interface NSRunLoop (Monotonic)
- (void)runForMonotonicInterval:(NSTimeInterval)seconds;
@end
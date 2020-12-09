#if TARGET_OS_SIMULATOR
/**
 * iOS-Runtime-Headers/PrivateFrameworks/UIKitCore.framework/UIKeyboardImpl.h
 */
@interface UIKeyboardImpl
+ (instancetype)sharedInstance;
/**
 * Modify software keyboard condition on simulators for over Xcode 6
 * This setting is global. The change applies to all instances of UIKeyboardImpl.
 *
 * Idea: https://chromium.googlesource.com/chromium/src/base/+/ababb4cf8b6049a642a2f361b1006a07561c2d96/test/test_support_ios.mm#41
 *
 * @param enabled Whether turn setAutomaticMinimizationEnabled on
 */
- (void)setAutomaticMinimizationEnabled:(BOOL)enabled;

/**
* Modify software keyboard condition on simulators for over Xcode 6
* This setting is global. The change applies to all instances of UIKeyboardImpl.
*
* Idea: https://chromium.googlesource.com/chromium/src/base/+/ababb4cf8b6049a642a2f361b1006a07561c2d96/test/test_support_ios.mm#41
*
* @param enabled Whether turn setSoftwareKeyboardShownByTouch on
*/
- (void)setSoftwareKeyboardShownByTouch:(BOOL)enabled;
@end
#endif  // TARGET_IPHONE_SIMULATOR

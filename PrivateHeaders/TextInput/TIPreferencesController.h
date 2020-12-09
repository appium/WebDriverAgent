/**
 * iOS-Runtime-Headers/PrivateFrameworks/TextInput.framework.
 * Text Input preferences controller to modify the keyboard preferences for iOS 8+.
 *
 * Note:
 * "autocorrection" will be PrivateFrameworks/TextInput.framework/TIKeyboardState.h in the future?
 */
@interface TIPreferencesController : NSObject

/**
 * Whether the autocorrection is enabled.
 */
@property BOOL autocorrectionEnabled;

/**
 * Whether the predication is enabled.
 * */
@property BOOL predictionEnabled;

/**
 The shared singleton instance.
 */
+ (instancetype)sharedPreferencesController;

/**
 Synchronise the change to save it on disk.
 */
- (void)synchronizePreferences;

/**
 * Modify the preference @c value by the @c key
 *
 * @param value The value to set it to @c key
 * @param key The key name to set @c value to
 */
- (void)setValue:(NSValue *)value forPreferenceKey:(NSString *)key;

/**
 * Get the preferenve by @c key
 *
 * @param key The key name to get the value
 * @return Whether the @c key is enabled
 */
- (BOOL)boolForPreferenceKey:(NSString *)key;
@end

//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

@class NSArray, NSNumber, NSString;

@protocol XCUIKeyboardKeyMap <NSObject>
@property(readonly, getter=isPrimary) BOOL primary;
- (NSArray *)inputsForText:(NSString *)arg1 currentFlags:(unsigned long long)arg2;
- (NSArray *)inputsForText:(NSString *)arg1;
- (NSNumber *)inputForKey:(NSString *)arg1 modifierFlags:(unsigned long long)arg2;
- (NSArray *)inputsToSetModifierFlags:(unsigned long long)arg1 currentFlags:(unsigned long long)arg2;
- (unsigned long long)uniqueKeyboardType:(unsigned long long)arg1;
- (BOOL)supportsKeyboardType:(unsigned long long)arg1;
@end


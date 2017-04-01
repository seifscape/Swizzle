//
//  TBTweak.h
//  TBTweakViewController
//
//  Created by Tanner on 8/17/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "TBMethodHook.h"


NS_ASSUME_NONNULL_BEGIN
/// A class to make toggleable "tweaks" at runtime.
/// Simply provide a `TBMethodHook` instance and call `tryEnable:`.
///
/// @note Two `TBTweak` instances are considered equal only if their `hook`s are equal.
@interface TBTweak : NSObject <NSCoding>

/// @return nil if `hook` was nil
+ (nullable instancetype)tweakWithHook:(nullable TBMethodHook *)hook;
/// Convenience method to initialize the `hook` property to hook an INSTANCE method.
+ (nullable instancetype)tweakWithTarget:(Class)target instanceMethod:(SEL)action;
/// Convenience method to initialize the `hook` property to hook a CLASS method.
+ (nullable instancetype)tweakWithTarget:(Class)target method:(SEL)action;

/// The block only calls back (executes) if there was an error.
- (void)tryEnable:(void(^)(NSError *error))failureBlock;
- (void)disable;

/// Whether the tweak is enabled.
@property (nonatomic, readonly) BOOL         enabled;
/// Use this property to modify the tweak.
/// @note If modified while the tweak is enabled,
/// the tweak must be toggled off and on again to take effect.
@property (nonatomic, readonly) TBMethodHook *hook;

@property (nonatomic, readonly) NSString *sortByThis;

@end
NS_ASSUME_NONNULL_END

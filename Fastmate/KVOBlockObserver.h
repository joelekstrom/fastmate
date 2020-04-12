#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KVOBlockObserver : NSObject

- (instancetype)initWithObject:(id)object keyPath:(NSString *)keyPath block:(void(^)(id value))block;

// Convenience which calls block directly with the current value
+ (instancetype)observe:(id)object keyPath:(NSString *)keyPath block:(void(^)(id value))block;

// Convenience for boolean values
- (instancetype)initWithObject:(id)object keyPath:(NSString *)keyPath boolBlock:(void(^)(BOOL value))block;
+ (instancetype)observe:(id)object keyPath:(NSString *)keyPath boolBlock:(void(^)(BOOL value))block;

// Convenience for user defaults
+ (instancetype)observeUserDefaultsKey:(NSString *)key block:(void(^)(BOOL value))block;

@end

NS_ASSUME_NONNULL_END

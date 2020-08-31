//
//  NotificationCenter.h
//  Fastmate
//
//  Created by Joel Ekström on 2020-04-28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FastmateNotificationCenter;

@protocol FastmateNotificationCenterDelegate
- (void)notificationCenter:(FastmateNotificationCenter *)center notificationClickedWithIdentifier:(NSString *)identifier;
@end

@interface FastmateNotificationCenter : NSObject

+ (instancetype)sharedInstance;
- (void)registerForNotifications;
- (void)postNotificationWithIdentifier:(NSString *)identifier title:(NSString *)title body:(NSString *)body;

@property (nonatomic, weak) id<FastmateNotificationCenterDelegate> delegate;

@end

NS_ASSUME_NONNULL_END

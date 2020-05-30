//
//  NotificationCenter.m
//  Fastmate
//
//  Created by Joel Ekström on 2020-04-28.
//

@import UserNotifications;

#import "NotificationCenter.h"

@interface NotificationCenter() <UNUserNotificationCenterDelegate, NSUserNotificationCenterDelegate>

@end

@implementation NotificationCenter

+ (instancetype)sharedInstance {
    static NotificationCenter *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)registerForNotifications {
    if (@available(macOS 10.14, *)) {
        // NOTE: This is an attempt to fix a crash that's happening for certain users:
        // https://stackoverflow.com/questions/43840090/calling-unusernotificationcenter-current-getpendingnotificationrequests-crashe
        [UNUserNotificationCenter.currentNotificationCenter removeAllPendingNotificationRequests];
        UNUserNotificationCenter.currentNotificationCenter.delegate = self;

        UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionProvidesAppNotificationSettings | UNAuthorizationOptionBadge;
        [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:options
                                                                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
            NSLog(@"Notification authorization granted: %@", granted ? @"yes" : @"no");
        }];
    } else {
        [NSUserNotificationCenter.defaultUserNotificationCenter setDelegate:self];
    }
}

- (void)postNotificationWithIdentifier:(NSString *)identifier title:(NSString *)title body:(NSString *)body {
    if (@available(macOS 10.14, *)) {
        UNMutableNotificationContent *content = [UNMutableNotificationContent new];
        content.title = title;
        content.subtitle = body;

        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                              content:content
                                                                              trigger:nil];

        [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            NSLog(@"%@", error);
        }];
    } else {
        NSUserNotification *notification = [NSUserNotification new];
        notification.identifier = identifier;
        notification.title = title;
        notification.subtitle = body;
        notification.soundName = NSUserNotificationDefaultSoundName;
        [NSUserNotificationCenter.defaultUserNotificationCenter deliverNotification:notification];
    }
}

#pragma mark - NSUserNotificationCenterDelegate

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    [self.delegate notificationCenter:self notificationClickedWithIdentifier:notification.identifier];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler API_AVAILABLE(macos(10.14)) {
    NSString *identifier = response.notification.request.identifier;
    [self.delegate notificationCenter:self notificationClickedWithIdentifier:identifier];
    completionHandler();
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler API_AVAILABLE(macos(10.14)) {
    completionHandler(UNNotificationPresentationOptionAlert);
}


@end

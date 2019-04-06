//
//  VersionChecker.h
//  Fastmate
//
//  Created by Joel Ekström on 2019-04-06.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol VersionCheckerDelegate <NSObject>
- (void)versionCheckerDidFindNewVersion:(NSString *)latestVersion withURL:(NSURL *)latestVersionURL;
- (void)versionCheckerDidNotFindNewVersion;
@end

@interface VersionChecker : NSObject
+ (instancetype)sharedInstance;
- (void)checkForUpdates;
@property (nonatomic, weak) id<VersionCheckerDelegate> delegate;
@end

NS_ASSUME_NONNULL_END

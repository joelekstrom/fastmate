#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol VersionCheckerDelegate <NSObject>
- (void)versionCheckerDidFindNewVersion:(NSString *)latestVersion withURL:(NSURL *)latestVersionURL;
- (void)versionCheckerDidNotFindNewVersion;
@end

@interface VersionChecker : NSObject
+ (instancetype)sharedInstance;
- (void)checkForUpdates;
- (NSDate *)lastUpdateCheckDate;
@property (nonatomic, weak) id<VersionCheckerDelegate> delegate;
@end

NS_ASSUME_NONNULL_END

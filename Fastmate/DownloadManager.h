#import <Foundation/Foundation.h>

typedef void(^loadProgressBlock)(float progress);
typedef void(^speedBlock)(NSString *speed);

@interface DownloadManager : NSObject

- (void)downloadWithURL:(NSURL *)url;

@property (nonatomic ,copy) loadProgressBlock loadProgress;

- (void)pause;
- (void)resume ;

@end

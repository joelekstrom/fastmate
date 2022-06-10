#import <Foundation/Foundation.h>

@interface DownloadManager : NSObject

- (void)downloadWithURL:(NSURL *)url;
- (void)cancel;
- (void)pause;
- (void)resume ;

@end

#import <Foundation/Foundation.h>

@interface FileDownloadTask : NSObject

- (void)downloadWithURL:(NSURL *)url;
- (void)clean;

@end

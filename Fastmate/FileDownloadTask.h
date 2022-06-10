#import <Foundation/Foundation.h>

@interface FileDownloadTask : NSObject

- (void)downloadWithURL:(NSURL *)url;
- (void)cancel;
- (void)pause;
- (void)resume ;

@end

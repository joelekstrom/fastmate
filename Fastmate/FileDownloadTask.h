#import <Foundation/Foundation.h>
#import "FileDownloadManager.h"

@interface FileDownloadTask : NSObject

- (instancetype)initWithURL:(NSURL *)url fileDownloadManager:(FileDownloadManager *)fileDownloadManager;
- (void)finish;
- (void)cancel;
- (void)clean;

@end

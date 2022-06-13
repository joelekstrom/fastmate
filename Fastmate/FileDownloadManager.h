#import <Foundation/Foundation.h>

@interface FileDownloadManager : NSObject

- (void)addDownloadWithURL:(NSURL *)url;
- (void)removeDownloadWithURL:(NSURL *)url;
- (void)existingDownloadAlert:(NSString *)fileName;

@end

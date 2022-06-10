#import "FileDownloadTask.h"
#import "FileDownloadUtil.h"
@import WebKit;

@interface FileDownloadTask () <NSURLSessionDataDelegate>
{
    long long _totalBytes;
    long long _receivedBytes;
    int64_t _lastReceivedBytes;
}

@property (nonatomic, strong) NSURLSession *session ;
@property (nonatomic, strong) NSOutputStream *outStream;
@property (nonatomic, weak) NSURLSessionTask *task;
@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic, strong) NSString *downloadedPath;
@property (nonatomic, strong) NSString *downloadingPath;

@end

@implementation FileDownloadTask

- (void)downloadWithURL:(NSURL *)url {
    NSString *fileName = url.lastPathComponent;
    // FIXME: this should be made user configurable in settings
    NSString *downloadsPath = [[NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES) firstObject] stringByResolvingSymlinksInPath];
    NSString *availableFilename = [FileDownloadUtil nextAvailableFilenameAtPath:downloadsPath proposedFilename:fileName];
    self.downloadedPath = [downloadsPath stringByAppendingPathComponent:availableFilename];
    self.downloadingPath = [self.downloadedPath stringByAppendingString:@".fmdownload"];

    if([FileDownloadUtil fileExists:self.downloadedPath]) {
        NSLog(@"File already exists");
        return;
    }
    
    _receivedBytes = [FileDownloadUtil getFileSize:self.downloadingPath];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:0];
    [request setValue:[NSString stringWithFormat:@"bytes=%lld-",self->_receivedBytes] forHTTPHeaderField:@"Range"];

    NSURLSessionConfiguration *conf = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:fileName];
    self.session = [NSURLSession sessionWithConfiguration:conf delegate:self delegateQueue:nil];
    
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request];
    self.task = dataTask ;
    self.outStream = [NSOutputStream outputStreamToFileAtPath:self.downloadingPath append:YES];
        
    [dataTask resume];

    _lastReceivedBytes = 0;

}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    _totalBytes = [httpResponse.allHeaderFields[@"Content-Length"] longLongValue];
    if (httpResponse.allHeaderFields[@"Content-Range"]) {
        NSString *rangeStr = httpResponse.allHeaderFields[@"Content-Range"];
        _totalBytes = [[[rangeStr componentsSeparatedByString:@"/"]lastObject]longLongValue];
    }
    if (_receivedBytes == _totalBytes) {
        [FileDownloadUtil moveFile:self.downloadingPath toPath:self.downloadedPath];
        NSLog(@"Already downloaded file - not doing anything");
        completionHandler(NSURLSessionResponseCancel);
        return;
    }
    if (_receivedBytes > _totalBytes) {
        // FIXME: not sure what's the way to go here... re-download directly?
        [FileDownloadUtil removeFile:self.downloadingPath];
        completionHandler(NSURLSessionResponseCancel);
        NSLog(@"Something went wrong, we should download this file again");
        [self downloadWithURL:dataTask.originalRequest.URL];
        return;
    }
    
    NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
        @"NSProgressFileOperationKindDownloading", @"NSProgressFileOperationKindKey",
        [NSURL fileURLWithPath:self.downloadingPath], @"NSProgressFileURLKey",
        nil];
    
    self.progress = [[NSProgress alloc] initWithParent:nil userInfo:info];
    [self.progress setKind:@"NSProgressKindFile"];
    [self.progress setPausable:YES];
    [self.progress setCancellable:YES];
    [self.progress setTotalUnitCount:_totalBytes];
    [self.progress publish];
    
    // Add handlers
    __weak typeof(self) weakSelf = self;
    self.progress.cancellationHandler = ^{
        [FileDownloadUtil removeFile:[weakSelf downloadingPath]];
        [weakSelf clean];
    };
        
    self.outStream = [NSOutputStream outputStreamToFileAtPath:self.downloadingPath append:YES];
    [self.outStream open];
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    _receivedBytes += data.length;
    [self.progress setCompletedUnitCount:_receivedBytes];
    [self.outStream write:data.bytes maxLength:data.length];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {

    // alwasy clean up
    [self clean];
    
    if(error) {
        if(error.code == NSURLErrorCancelled) {
            NSLog(@"Download cancelled");
        } else {
            NSLog(@"Something went wrong: %@", error);
        }
        return;
    }
    
    [FileDownloadUtil moveFile:self.downloadingPath toPath:self.downloadedPath];
    
    // FIXME: this should be configurable in settings? OR this should be skipped?
    NSSet *extSet = [NSSet setWithObjects:@"doc",@"docx",@"ppt",@"pptx",@"xls",@"xlsx",@"pdf",@"png",@"jpg",nil];
    if ([extSet containsObject:self.downloadedPath.pathExtension]) {
        [NSWorkspace.sharedWorkspace openFile:self.downloadedPath];
    }

}

- (void)clean {
    [self.session invalidateAndCancel];
    [self.outStream close];
    [self.progress unpublish];
    self.session = nil;
}

@end

#import "FileDownloadTask.h"
#import "FileDownloadManager.h"
#import "FileDownloadUtil.h"
#import "UserDefaultsKeys.h"
@import WebKit;

@interface FileDownloadTask () <NSURLSessionDataDelegate>
{
    long long _totalBytes;
    long long _receivedBytes;
    int64_t _lastReceivedBytes;

}

@property (nonatomic, strong) NSURLSession *session ;
@property (nonatomic, strong) NSOutputStream *outStream;
@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic, strong) FileDownloadManager *fileDownloadManager;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *downloadedPath;
@property (nonatomic, strong) NSString *downloadingPath;

@end

@implementation FileDownloadTask

- (instancetype)initWithURL:(NSURL *)url fileDownloadManager:(FileDownloadManager *)fileDownloadManager {
    self.url = url;
    self.fileName = url.lastPathComponent;
    self.fileDownloadManager = fileDownloadManager;
    
    NSString *downloadsPath = [NSUserDefaults.standardUserDefaults stringForKey:DownloadsPathKey];
    
    NSURLSessionConfiguration *conf = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:self.fileName];
    self.session = [NSURLSession sessionWithConfiguration:conf delegate:self delegateQueue:nil];
    
    DownloadBehaviorType downloadBehaviorType = [NSUserDefaults.standardUserDefaults integerForKey:DownloadBehaviorKey];
    if(downloadBehaviorType == DownloadBehaviorTypeAsk) {
        self.downloadedPath = [downloadsPath stringByAppendingPathComponent:self.fileName];
        if([FileDownloadUtil fileExists:self.downloadedPath]) {
            NSAlert *alert = [NSAlert new];
            alert.messageText = [NSString stringWithFormat:@"File \"%@\" already exists", self.fileName];
            alert.window.defaultButtonCell = [alert addButtonWithTitle:@"Keep"].cell;
            [alert addButtonWithTitle:@"Overwrite"];
            alert.alertStyle = NSAlertStyleInformational;
            NSModalResponse result = [alert runModal];
            if (result == NSAlertFirstButtonReturn) {
                downloadBehaviorType = DownloadBehaviorTypeKeep;
            } else {
                downloadBehaviorType = DownloadBehaviorTypeOverwrite;
            }
        }
    }

    if(downloadBehaviorType == DownloadBehaviorTypeKeep) {
        NSString *availableFilename = [FileDownloadUtil nextAvailableFilenameAtPath:downloadsPath proposedFilename:self.fileName];
        self.downloadedPath = [downloadsPath stringByAppendingPathComponent:availableFilename];
    } else if(downloadBehaviorType == DownloadBehaviorTypeOverwrite) {
        self.downloadedPath = [downloadsPath stringByAppendingPathComponent:self.fileName];
    }
        
    self.downloadingPath = [self.downloadedPath stringByAppendingString:@".fmdownload"];
    
    _receivedBytes = [FileDownloadUtil getFileSize:self.downloadingPath];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:0];
    [request setValue:[NSString stringWithFormat:@"bytes=%lld-",self->_receivedBytes] forHTTPHeaderField:@"Range"];

    self.outStream = [NSOutputStream outputStreamToFileAtPath:self.downloadingPath append:YES];
    [[self.session dataTaskWithRequest:request] resume];

    _lastReceivedBytes = 0;

    return self;
}

- (void)finish {
    [self.session finishTasksAndInvalidate];
    [self clean];
}

- (void)cancel {
    [self.session invalidateAndCancel];
    [self clean];
}

- (void)clean {
    [self.outStream close];
    [self.progress unpublish];
    self.session = nil;
    [self.fileDownloadManager removeDownloadWithURL:self.url];
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
        completionHandler(NSURLSessionResponseCancel);
        return;
    }
    if (_receivedBytes > _totalBytes) {
        [FileDownloadUtil removeFile:self.downloadingPath];
        completionHandler(NSURLSessionResponseCancel);
        NSLog(@"Something went wrong - more bytes received than expected");
        return;
    }
    
    NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
        @"NSProgressFileOperationKindDownloading", @"NSProgressFileOperationKindKey",
        [NSURL fileURLWithPath:self.downloadingPath], @"NSProgressFileURLKey",
        nil];
    
    self.progress = [[NSProgress alloc] initWithParent:nil userInfo:info];
    [self.progress setKind:@"NSProgressKindFile"];
    [self.progress setPausable:NO];
    [self.progress setCancellable:YES];
    [self.progress setTotalUnitCount:_totalBytes];
    [self.progress publish];
    
    // Add handlers
    __weak typeof(self) weakSelf = self;
    self.progress.cancellationHandler = ^{
        [FileDownloadUtil removeFile:[weakSelf downloadingPath]];
        [weakSelf clean];
    };
        
    [self.outStream open];
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    _receivedBytes += data.length;
    [self.progress setCompletedUnitCount:_receivedBytes];
    [self.outStream write:data.bytes maxLength:data.length];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {

    if(error) {
        if(error.code == NSURLErrorCancelled) {
            NSLog(@"Download cancelled");
        } else {
            NSLog(@"Something went wrong: %@", error);
        }
        [self cancel];
        return;
    }
    
    [self finish];
    
    [FileDownloadUtil moveFile:self.downloadingPath toPath:self.downloadedPath];
    
    if ([NSUserDefaults.standardUserDefaults boolForKey:@"shouldOpenSafeDownloads"]) {
        NSSet *extSet = [NSSet setWithObjects:@"doc",@"docx",@"ppt",@"pptx",@"xls",@"xlsx",@"pdf",@"png",@"jpg",nil];
        if ([extSet containsObject:self.downloadedPath.pathExtension]) {
            [NSWorkspace.sharedWorkspace openFile:self.downloadedPath];
        }
    }

}

@end

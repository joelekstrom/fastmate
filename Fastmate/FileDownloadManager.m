#import "FileDownloadManager.h"
#import "FileDownloadTask.h"
#import "UserDefaultsKeys.h"
@import WebKit;

@interface FileDownloadManager ()

@property (atomic, strong) NSMutableDictionary *sessions;

@end

@implementation FileDownloadManager

- (void)addDownloadWithURL:(NSURL *)url {
    NSString *fileName = url.lastPathComponent;
    
    // lazy loading
    if(self.sessions == nil) {
        self.sessions = [[NSMutableDictionary alloc] init];
    }

    if([self.sessions objectForKey:fileName] == nil) {
        FileDownloadTask *fileDownloadTask = [[FileDownloadTask alloc] initWithURL:url fileDownloadManager:self];
        [self.sessions setObject:fileDownloadTask forKey:fileName];
    } else {
        [self existingDownloadAlert:fileName];
    }
}
    
- (void)removeDownloadWithURL:(NSURL *)url {
    NSString *fileName = url.lastPathComponent;
    [self.sessions removeObjectForKey:fileName];
}

- (void)existingDownloadAlert:(NSString *)fileName {
    NSWindow *mainWindow = [[NSApplication sharedApplication] mainWindow];
    NSAlert *alert = [NSAlert new];
    alert.messageText = [NSString stringWithFormat:@"File \"%@\" is already being downloaded", fileName];
    [alert addButtonWithTitle:@"OK"];
    alert.alertStyle = NSAlertStyleInformational;
    [alert beginSheetModalForWindow:mainWindow completionHandler:nil];
}

@end

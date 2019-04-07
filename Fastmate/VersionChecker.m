//
//  VersionChecker.m
//  Fastmate
//
//  Created by Joel Ekström on 2019-04-06.
//

#import "VersionChecker.h"

@interface VersionChecker() <NSURLSessionTaskDelegate>

@property (nonatomic, strong) NSURLSession *session;

@end

@implementation VersionChecker

+ (instancetype)sharedInstance
{
    static VersionChecker *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    if (self = [super init]) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:NSOperationQueue.mainQueue];
    }
    return self;
}

- (NSDate *)lastUpdateCheckDate
{
    NSDate *date = [NSUserDefaults.standardUserDefaults objectForKey:NSStringFromSelector(@selector(lastUpdateCheckDate))];
    if (date == nil) {
        date = [NSDate date];
        [NSUserDefaults.standardUserDefaults setObject:date forKey:NSStringFromSelector(@selector(lastUpdateCheckDate))];
    }
    return date;
}

- (void)checkForUpdates
{
    [[self.session dataTaskWithURL:[NSURL URLWithString:@"https://github.com/joelekstrom/fastmate/releases/latest"]] resume];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler;
{
    [task cancel];
    [NSUserDefaults.standardUserDefaults setObject:[NSDate date] forKey:NSStringFromSelector(@selector(lastUpdateCheckDate))];

    NSString *currentVersion = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    currentVersion = [NSString stringWithFormat:@"v%@", currentVersion];
    NSString *latestVersion = request.URL.lastPathComponent;

    switch ([latestVersion compare:currentVersion]) {
        case NSOrderedSame:
        case NSOrderedAscending:
            [self.delegate versionCheckerDidNotFindNewVersion]; break;
        case NSOrderedDescending:
            [self.delegate versionCheckerDidFindNewVersion:latestVersion withURL:request.URL]; break;
    }
}

@end

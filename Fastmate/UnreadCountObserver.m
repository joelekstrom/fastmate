#import "UnreadCountObserver.h"
#import "KVOBlockObserver.h"
#import "UserDefaultsKeys.h"

@interface UnreadCountObserver()

@property (nonatomic, readonly) NSUInteger unreadCount;
@property (nonatomic, strong) NSArray *observers;

@end

@implementation UnreadCountObserver

- (instancetype)init {
    if (self = [super init]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self registerObservers];
        });
    }
    return self;
}

- (void)registerObservers {
    void (^updateBlock)(id) = ^(id _) {
        [self updateStatusBarIndicator];
        [self updateDockIndicator];
    };

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    self.observers = @[
        [[KVOBlockObserver alloc] initWithObject:defaults keyPath:ShouldShowUnreadMailIndicatorKey block:updateBlock],
        [[KVOBlockObserver alloc] initWithObject:defaults keyPath:ShouldShowUnreadMailInDockKey block:updateBlock],
        [[KVOBlockObserver alloc] initWithObject:defaults keyPath:ShouldShowUnreadMailCountInDockKey block:updateBlock],
        [[KVOBlockObserver alloc] initWithObject:defaults keyPath:ShouldShowStatusBarIconKey block:updateBlock],
        [[KVOBlockObserver alloc] initWithObject:defaults keyPath:ShouldShowUnreadMailInStatusBarKey block:updateBlock],
        [[KVOBlockObserver alloc] initWithObject:defaults keyPath:WatchedFolderTypeKey block:updateBlock],
        [[KVOBlockObserver alloc] initWithObject:defaults keyPath:WatchedFoldersKey block:updateBlock],
        [[KVOBlockObserver alloc] initWithObject:self keyPath:@"webViewController.mailboxes" block:updateBlock],
    ];
    updateBlock(nil);
}

- (WatchedFolderType)watchedFolderType
{
    return [NSUserDefaults.standardUserDefaults integerForKey:WatchedFolderTypeKey];
}

- (NSArray<NSString *> *)watchedFolders
{
    NSString *watchedFoldersString = [NSUserDefaults.standardUserDefaults stringForKey:WatchedFoldersKey];
    NSArray *watchedFolders = [watchedFoldersString componentsSeparatedByString:@","];
    NSMutableArray *normalizedFolders = [NSMutableArray new];
    for (NSString *folder in watchedFolders) {
        [normalizedFolders addObject:[folder stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    }
    return normalizedFolders;
}

- (NSUInteger)getUnreadCountFromTitle
{
    NSString *title = [self.webViewController valueForKeyPath:@"webView.title"];

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^(\\d+) •" options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSTextCheckingResult *result = [regex firstMatchInString:title options:0 range:NSMakeRange(0, title.length)];
    if (result && result.numberOfRanges > 1) {
        NSString *unreadCountString = [title substringWithRange:[result rangeAtIndex:1]];
        return unreadCountString.integerValue;
    }
    return 0;
}

- (NSUInteger)unreadCount
{
    NSUInteger totalCount = 0;
    switch ([self watchedFolderType]) {
        case WatchedFolderTypeDefault:
            totalCount = [self getUnreadCountFromTitle];
            break;
        case WatchedFolderTypeSpecific: {
            for (NSString *folder in [self watchedFolders]) {
                totalCount += self.webViewController.mailboxes[folder].integerValue;
            }
            break;
        }
        case WatchedFolderTypeAll:
            for (NSNumber *count in self.webViewController.mailboxes.allValues) {
                totalCount += count.integerValue;
            }
            break;
    }
    return totalCount;
}

- (void)updateDockIndicator {
    NSString *badgeLabel = nil;
    if ([self shouldShowDockIndicator]) {
        badgeLabel = [self shouldShowCountInDock] ? [NSString stringWithFormat:@"%ld", self.unreadCount] : @" ";
    }
    NSApplication.sharedApplication.dockTile.badgeLabel = badgeLabel;
}

- (void)updateStatusBarIndicator {
    self.statusItem.image = [NSImage imageNamed:[self shouldShowStatusBarIndicator] ? @"status-bar-unread" : @"status-bar"];
}

- (void)setStatusItem:(NSStatusItem *)statusItem {
    _statusItem = statusItem;
    [self updateStatusBarIndicator];
}

- (BOOL)shouldShowStatusBarIndicator {
    return self.statusItem
        && self.unreadCount > 0
        && [NSUserDefaults.standardUserDefaults boolForKey:ShouldShowUnreadMailInStatusBarKey]
        && [NSUserDefaults.standardUserDefaults boolForKey:ShouldShowUnreadMailIndicatorKey];
}

- (BOOL)shouldShowDockIndicator {
    return self.unreadCount > 0
        && [NSUserDefaults.standardUserDefaults boolForKey:ShouldShowUnreadMailInDockKey]
        && [NSUserDefaults.standardUserDefaults boolForKey:ShouldShowUnreadMailIndicatorKey];
}

- (BOOL)shouldShowCountInDock {
    return [NSUserDefaults.standardUserDefaults boolForKey:ShouldShowUnreadMailCountInDockKey];
}

@end

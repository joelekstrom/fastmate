#import "UnreadCountObserver.h"
#import "KVOBlockObserver.h"
#import "UserDefaultsKeys.h"

@interface UnreadCountObserver()

@property (nonatomic, assign) NSUInteger unreadCount;
@property (nonatomic, strong) NSArray *observers;

@property (nonatomic, copy) NSString *webViewTitle;
@property (nonatomic, copy) NSDictionary<NSString *, NSNumber *> *mailBoxes;

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
    __weak typeof(self) weakSelf = self;
    void (^updateBlock)(id) = ^(id _) {
        [weakSelf updateUnreadCount];
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
        [[KVOBlockObserver alloc] initWithObject:self keyPath:@"webViewController.mailboxes" block:^(NSDictionary *mailboxes) {
            weakSelf.mailBoxes = mailboxes;
        }],
        [[KVOBlockObserver alloc] initWithObject:self keyPath:@"webViewController.webView.title" block:^(NSString *title) {
            weakSelf.webViewTitle = title;
        }],
    ];
    updateBlock(nil);
}

- (WatchedFolderType)watchedFolderType {
    return [NSUserDefaults.standardUserDefaults integerForKey:WatchedFolderTypeKey];
}

- (NSArray<NSString *> *)watchedFolders {
    NSString *watchedFoldersString = [NSUserDefaults.standardUserDefaults stringForKey:WatchedFoldersKey];
    NSArray *watchedFolders = [watchedFoldersString componentsSeparatedByString:@","];
    NSMutableArray *normalizedFolders = [NSMutableArray new];
    for (NSString *folder in watchedFolders) {
        [normalizedFolders addObject:[folder stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    }
    return normalizedFolders;
}

- (void)setWebViewTitle:(NSString *)title {
    if (![_webViewTitle isEqual:title]) {
        _webViewTitle = title;
        [self updateUnreadCount];
    }
}

- (void)setMailBoxes:(NSDictionary<NSString *,NSNumber *> *)mailBoxes {
    if (![_mailBoxes isEqual:mailBoxes]) {
        _mailBoxes = mailBoxes;
        [self updateUnreadCount];
    }
}

- (NSUInteger)titleUnreadCount {
    if (self.webViewTitle == nil) {
        return 0;
    }

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^(\\d+) •" options:NSRegularExpressionAnchorsMatchLines error:nil];
    NSTextCheckingResult *result = [regex firstMatchInString:self.webViewTitle options:0 range:NSMakeRange(0, self.webViewTitle.length)];
    if (result && result.numberOfRanges > 1) {
        NSString *unreadCountString = [self.webViewTitle substringWithRange:[result rangeAtIndex:1]];
        return unreadCountString.integerValue;
    }
    return 0;
}

- (void)updateUnreadCount {
    NSUInteger totalCount = 0;
    switch ([self watchedFolderType]) {
        case WatchedFolderTypeDefault:
            totalCount = self.titleUnreadCount;
            break;
        case WatchedFolderTypeSpecific: {
            for (NSString *folder in [self watchedFolders]) {
                totalCount += self.mailBoxes[folder].integerValue;
            }
            break;
        }
        case WatchedFolderTypeAll:
            for (NSNumber *count in self.mailBoxes.allValues) {
                totalCount += count.integerValue;
            }
            break;
    }

    self.unreadCount = totalCount;
    [self updateDockIndicator];
    [self updateStatusBarIndicator];
}

- (void)updateDockIndicator {
    NSString *badgeLabel = nil;
    if ([self shouldShowDockIndicator]) {
        badgeLabel = [self shouldShowCountInDock] ? [NSString stringWithFormat:@"%ld", self.unreadCount] : @" ";
    }
    NSApplication.sharedApplication.dockTile.badgeLabel = badgeLabel;
}

- (void)updateStatusBarIndicator {
    self.statusItem.button.image = [NSImage imageNamed:[self shouldShowStatusBarIndicator] ? @"status-bar-unread" : @"status-bar"];
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

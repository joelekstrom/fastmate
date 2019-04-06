#import "UnreadCountObserver.h"

typedef NS_ENUM(NSInteger, WatchedFolderType) {
    WatchedFolderTypeDefault,
    WatchedFolderTypeAll,
    WatchedFolderTypeSpecific
};

@interface UnreadCountObserver()

@property (nonatomic, weak) WebViewController *webViewController;
@property (nonatomic, readonly) NSUInteger unreadCount;

@end

@implementation UnreadCountObserver

static NSString * const MailboxesKeyPath = @"webViewController.mailboxes";
static NSString * const ShouldShowIndicatorUserDefaultsKey = @"shouldShowUnreadMailIndicator";
static NSString * const ShouldShowDockIndicatorUserDefaultsKey = @"shouldShowUnreadMailInDock";
static NSString * const ShouldShowMenuBarIndicatorUserDefaultsKey = @"shouldShowUnreadMailInStatusBar";
static NSString * const ShouldShowUnreadMailCountUserDefaultsKey = @"shouldShowUnreadMailCountInDock";
static NSString * const WatchedFolderTypeUserDefaultsKey = @"watchedFolderType";
static NSString * const WatchedFoldersUserDefaultsKey = @"watchedFolders";

static void *UnreadCountVisibilityKVOContext = &UnreadCountVisibilityKVOContext;

- (instancetype)initWithWebViewController:(WebViewController *)controller {
    if (self = [super init]) {
        self.webViewController = controller;
        [self addObserver:self forKeyPath:MailboxesKeyPath options:NSKeyValueObservingOptionNew context:UnreadCountVisibilityKVOContext];

        for (NSString *keyPath in @[ShouldShowIndicatorUserDefaultsKey, ShouldShowDockIndicatorUserDefaultsKey, ShouldShowMenuBarIndicatorUserDefaultsKey, ShouldShowUnreadMailCountUserDefaultsKey, WatchedFolderTypeUserDefaultsKey, WatchedFoldersUserDefaultsKey]) {
            [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:keyPath options:0 context:UnreadCountVisibilityKVOContext];
        }
    }
    return self;
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:MailboxesKeyPath];

    for (NSString *keyPath in @[ShouldShowIndicatorUserDefaultsKey, ShouldShowDockIndicatorUserDefaultsKey, ShouldShowMenuBarIndicatorUserDefaultsKey, ShouldShowUnreadMailCountUserDefaultsKey, WatchedFolderTypeUserDefaultsKey, WatchedFoldersUserDefaultsKey]) {
        [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:keyPath context:UnreadCountVisibilityKVOContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == UnreadCountVisibilityKVOContext) {
        [self updateStatusBarIndicator];
        [self updateDockIndicator];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (WatchedFolderType)watchedFolderType
{
    return [NSUserDefaults.standardUserDefaults integerForKey:WatchedFolderTypeUserDefaultsKey];
}

- (NSArray<NSString *> *)watchedFolders
{
    NSString *watchedFoldersString = [NSUserDefaults.standardUserDefaults stringForKey:WatchedFoldersUserDefaultsKey];
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
    NSRange unreadCountRange = [title rangeOfString:@"^\\(\\d+\\)" options:NSRegularExpressionSearch];
    if (unreadCountRange.location == NSNotFound) {
        return 0;
    } else {
        NSString *unreadString = [title substringWithRange:unreadCountRange];
        NSCharacterSet *decimalCharacterSet = [NSCharacterSet decimalDigitCharacterSet];
        return [[unreadString stringByTrimmingCharactersInSet:decimalCharacterSet.invertedSet] integerValue];
    }
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
    return self.statusItem && self.unreadCount > 0 && [NSUserDefaults.standardUserDefaults boolForKey:ShouldShowMenuBarIndicatorUserDefaultsKey] && [NSUserDefaults.standardUserDefaults boolForKey:ShouldShowIndicatorUserDefaultsKey];
}

- (BOOL)shouldShowDockIndicator {
    return self.unreadCount > 0 && [NSUserDefaults.standardUserDefaults boolForKey:ShouldShowDockIndicatorUserDefaultsKey] && [NSUserDefaults.standardUserDefaults boolForKey:ShouldShowIndicatorUserDefaultsKey];
}

- (BOOL)shouldShowCountInDock {
    return [NSUserDefaults.standardUserDefaults boolForKey:ShouldShowUnreadMailCountUserDefaultsKey];
}

@end

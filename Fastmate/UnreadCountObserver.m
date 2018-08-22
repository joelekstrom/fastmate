#import "UnreadCountObserver.h"

@interface UnreadCountObserver()

@property (nonatomic, weak) WebViewController *webViewController;
@property (nonatomic, assign) NSUInteger unreadCount;

@end

@implementation UnreadCountObserver

static NSString * const TitleKeyPath = @"webViewController.webView.title";
static NSString * const ShouldShowIndicatorUserDefaultsKey = @"shouldShowUnreadMailIndicator";
static NSString * const ShouldShowDockIndicatorUserDefaultsKey = @"shouldShowUnreadMailInDock";
static NSString * const ShouldShowMenuBarIndicatorUserDefaultsKey = @"shouldShowUnreadMailInStatusBar";
static NSString * const ShouldShowUnreadMailCountUserDefaultsKey = @"shouldShowUnreadMailCountInDock";

static void *UnreadCountObserverKVOContext = &UnreadCountObserverKVOContext;

- (instancetype)initWithWebViewController:(WebViewController *)controller {
    if (self = [super init]) {
        self.webViewController = controller;
        [self addObserver:self forKeyPath:TitleKeyPath options:NSKeyValueObservingOptionNew context:UnreadCountObserverKVOContext];
        [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:ShouldShowIndicatorUserDefaultsKey options:0 context:UnreadCountObserverKVOContext];
        [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:ShouldShowDockIndicatorUserDefaultsKey options:0 context:UnreadCountObserverKVOContext];
        [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:ShouldShowMenuBarIndicatorUserDefaultsKey options:0 context:UnreadCountObserverKVOContext];
        [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:ShouldShowUnreadMailCountUserDefaultsKey options:0 context:UnreadCountObserverKVOContext];
    }
    return self;
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:TitleKeyPath];
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:ShouldShowIndicatorUserDefaultsKey context:UnreadCountObserverKVOContext];
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:ShouldShowDockIndicatorUserDefaultsKey context:UnreadCountObserverKVOContext];
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:ShouldShowMenuBarIndicatorUserDefaultsKey context:UnreadCountObserverKVOContext];
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:ShouldShowUnreadMailCountUserDefaultsKey context:UnreadCountObserverKVOContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == self && [keyPath isEqualToString:TitleKeyPath]) {
        [self webViewTitleDidChange:change[NSKeyValueChangeNewKey]];
    } else if (object == NSUserDefaults.standardUserDefaults && context == UnreadCountObserverKVOContext) {
        [self updateStatusBarIndicator];
        [self updateDockIndicator];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)webViewTitleDidChange:(NSString *)newTitle {
    NSRange unreadCountRange = [newTitle rangeOfString:@"^\\(\\d+\\)" options:NSRegularExpressionSearch];
    if (unreadCountRange.location == NSNotFound) {
        [self setUnreadCount:0];
    } else {
        NSString *unreadString = [newTitle substringWithRange:unreadCountRange];
        NSCharacterSet *decimalCharacterSet = [NSCharacterSet decimalDigitCharacterSet];
        NSInteger unreadCount = [[unreadString stringByTrimmingCharactersInSet:decimalCharacterSet.invertedSet] integerValue];
        [self setUnreadCount:unreadCount];
    }
}

- (void)setUnreadCount:(NSUInteger)unreadCount {
    _unreadCount = unreadCount;
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

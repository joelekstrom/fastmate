#import "AppDelegate.h"
#import "WebViewController.h"
#import "UnreadCountObserver.h"
#import "SettingsViewController.h"

@interface AppDelegate ()

@property (nonatomic, strong) WebViewController *mainWebViewController;
@property (nonatomic, strong) UnreadCountObserver *unreadCountObserver;
@property (nonatomic, strong) NSStatusItem *statusItem;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.mainWebViewController = (WebViewController *)NSApplication.sharedApplication.mainWindow.contentViewController;
    self.unreadCountObserver = [[UnreadCountObserver alloc] initWithWebViewController:self.mainWebViewController];
    [NSAppleEventManager.sharedAppleEventManager setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];

    NSColor *windowColor = [NSKeyedUnarchiver unarchiveObjectWithData:[NSUserDefaults.standardUserDefaults dataForKey:@"lastUsedWindowColor"]];
    NSApplication.sharedApplication.mainWindow.backgroundColor = windowColor ?: [NSColor colorWithRed:0.27 green:0.34 blue:0.49 alpha:1.0];

    [self updateStatusItemVisibility];
    [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:@"iconVisibility" options:0 context:nil];
}

- (void)dealloc {
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:@"iconVisibility"];
}

- (void)handleURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSAppleEventDescriptor *directObjectDescriptor = [event paramDescriptorForKeyword:keyDirectObject];
    NSURL *mailtoURL = [NSURL URLWithString:directObjectDescriptor.stringValue];
    [self.mainWebViewController handleMailtoURL:mailtoURL];
}

- (IBAction)newDocument:(id)sender {
    [self.mainWebViewController composeNewEmail];
}

- (IBAction)performFindPanelAction:(id)sender {
    [self.mainWebViewController focusSearchField];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == NSUserDefaults.standardUserDefaults && [keyPath isEqualToString:@"iconVisibility"]) {
        [self updateStatusItemVisibility];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)updateStatusItemVisibility {
    FastmateIconVisibility visibility = [NSUserDefaults.standardUserDefaults integerForKey:@"iconVisibility"];
    if (visibility == FastmateIconVisibilityStatusBar || visibility == FastmateIconVisibilityBoth) {
        self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
        self.unreadCountObserver.statusItem = self.statusItem;
    } else {
        [NSStatusBar.systemStatusBar removeStatusItem:self.statusItem];
    }
}

@end

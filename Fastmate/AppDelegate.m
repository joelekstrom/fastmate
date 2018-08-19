#import "AppDelegate.h"
#import "WebViewController.h"
#import "UnreadCountObserver.h"

@interface AppDelegate ()

@property (nonatomic, strong) WebViewController *mainWebViewController;
@property (nonatomic, strong) UnreadCountObserver *unreadCountObserver;
@property (nonatomic, strong) NSStatusItem *statusItem;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.mainWebViewController = (WebViewController *)NSApplication.sharedApplication.mainWindow.contentViewController;
    self.unreadCountObserver = [[UnreadCountObserver alloc] initWithWebViewController:self.mainWebViewController];
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
    [NSAppleEventManager.sharedAppleEventManager setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];

    NSColor *windowColor = [NSKeyedUnarchiver unarchiveObjectWithData:[NSUserDefaults.standardUserDefaults dataForKey:@"lastUsedWindowColor"]];
    NSApplication.sharedApplication.mainWindow.backgroundColor = windowColor ?: [NSColor colorWithRed:0.27 green:0.34 blue:0.49 alpha:1.0];
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

@end

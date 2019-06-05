#import "AppDelegate.h"
#import "WebViewController.h"
#import "UnreadCountObserver.h"
#import "VersionChecker.h"

@interface AppDelegate () <VersionCheckerDelegate, NSUserNotificationCenterDelegate>

@property (nonatomic, strong) WebViewController *mainWebViewController;
@property (nonatomic, strong) UnreadCountObserver *unreadCountObserver;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, assign) BOOL isAutomaticUpdateCheck;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.mainWebViewController = (WebViewController *)NSApplication.sharedApplication.mainWindow.contentViewController;
    self.unreadCountObserver = [[UnreadCountObserver alloc] initWithWebViewController:self.mainWebViewController];
    [NSAppleEventManager.sharedAppleEventManager setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];

    NSColor *windowColor = [NSKeyedUnarchiver unarchiveObjectWithData:[NSUserDefaults.standardUserDefaults dataForKey:@"lastUsedWindowColor"]];
    NSApplication.sharedApplication.mainWindow.backgroundColor = windowColor ?: [NSColor colorWithRed:0.27 green:0.34 blue:0.49 alpha:1.0];

    [self updateStatusItemVisibility];
    [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:@"shouldShowStatusBarIcon" options:0 context:nil];
    [NSUserNotificationCenter.defaultUserNotificationCenter setDelegate:self];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [NSUserDefaults.standardUserDefaults registerDefaults:@{@"automaticUpdateChecks": @YES, @"shouldShowUnreadMailIndicator": @YES, @"shouldShowUnreadMailInDock": @YES, @"shouldShowUnreadMailCountInDock": @YES}];
    [self performAutomaticUpdateCheckIfNeeded];
}

- (void)dealloc {
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:@"shouldShowStatusBarIcon"];
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
    if (object == NSUserDefaults.standardUserDefaults && [keyPath isEqualToString:@"shouldShowStatusBarIcon"]) {
        [self updateStatusItemVisibility];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)updateStatusItemVisibility {
    if ([NSUserDefaults.standardUserDefaults boolForKey:@"shouldShowStatusBarIcon"]) {
        self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
        self.statusItem.target = self;
        self.statusItem.action = @selector(statusItemSelected:);
        self.unreadCountObserver.statusItem = self.statusItem;
    } else {
        [NSStatusBar.systemStatusBar removeStatusItem:self.statusItem];
    }
}

- (void)statusItemSelected:(id)sender {
    [NSApp unhide:sender];
    [NSApp activateIgnoringOtherApps:YES];
}

#pragma mark - Version checking

- (void)performAutomaticUpdateCheckIfNeeded {
    BOOL automaticUpdatesEnabled = [NSUserDefaults.standardUserDefaults boolForKey:@"automaticUpdateChecks"];
    if (!automaticUpdatesEnabled) {
        return;
    }

    NSDate *lastUpdateCheckDate = VersionChecker.sharedInstance.lastUpdateCheckDate;
    NSDateComponents *components = [NSCalendar.currentCalendar components:NSCalendarUnitDay fromDate:lastUpdateCheckDate toDate:NSDate.date options:0];
    if (components.day >= 7) {
        self.isAutomaticUpdateCheck = YES;
        [self checkForUpdates];
    }
}

- (IBAction)checkForUpdates:(id)sender {
    self.isAutomaticUpdateCheck = NO;
    [self checkForUpdates];
}

- (void)checkForUpdates {
    VersionChecker.sharedInstance.delegate = self;
    [VersionChecker.sharedInstance checkForUpdates];
}

- (void)versionCheckerDidFindNewVersion:(NSString *)latestVersion withURL:(NSURL *)latestVersionURL {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Take me there!"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.messageText = [NSString stringWithFormat:@"New version available: %@", latestVersion];
    alert.informativeText = [NSString stringWithFormat:@"You're currently at v%@", [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    alert.alertStyle = NSAlertStyleInformational;
    alert.showsSuppressionButton = self.isAutomaticUpdateCheck;
    alert.suppressionButton.title = @"Don't check for new versions automatically";
    [alert beginSheetModalForWindow:self.mainWebViewController.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [NSWorkspace.sharedWorkspace openURL:latestVersionURL];
        }

        if (alert.suppressionButton.state == NSOnState) {
            [NSUserDefaults.standardUserDefaults setBool:NO forKey:@"automaticUpdateChecks"];
        }
    }];
}

- (void)versionCheckerDidNotFindNewVersion {
    if (!self.isAutomaticUpdateCheck) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Nice!"];
        [alert setMessageText:@"Up to date!"];
        [alert setInformativeText:[NSString stringWithFormat:@"You're on the latest version. (v%@)", [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]]];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert beginSheetModalForWindow:self.mainWebViewController.view.window completionHandler:nil];
    }
}

#pragma mark - Notification handling

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    [self.mainWebViewController handleNotificationClickWithIdentifier:notification.identifier];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
}

@end

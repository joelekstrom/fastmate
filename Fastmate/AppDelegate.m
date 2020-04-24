#import "AppDelegate.h"
#import "WebViewController.h"
#import "UnreadCountObserver.h"
#import "KVOBlockObserver.h"
#import "UserDefaultsKeys.h"
#import "VersionChecker.h"
#import "PrintManager.h"

@import UserNotifications;

@interface AppDelegate () <VersionCheckerDelegate, NSUserNotificationCenterDelegate, UNUserNotificationCenterDelegate>

@property (nonatomic, strong) UnreadCountObserver *unreadCountObserver;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, assign) BOOL isAutomaticUpdateCheck;
@property (nonatomic, strong) id statusBarIconObserver;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSAppleEventManager.sharedAppleEventManager setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];

    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(workspaceDidWake:) name:NSWorkspaceDidWakeNotification object:NULL];

    if (@available(macOS 10.14, *)) {
        [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:UNAuthorizationOptionBadge | UNAuthorizationOptionAlert | UNAuthorizationOptionSound
                                                                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
            UNUserNotificationCenter.currentNotificationCenter.delegate = self;
        }];
    } else {
        [NSUserNotificationCenter.defaultUserNotificationCenter setDelegate:self];
    }

    self.statusBarIconObserver = [KVOBlockObserver observeUserDefaultsKey:ShouldShowStatusBarIconKey block:^(BOOL visible) {
        [self setStatusItemVisible:visible];
    }];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self createUserScriptsFolderIfNeeded];
    });
}

- (void)workspaceDidWake:(NSNotification *)notification {
    [self.mainWebViewController reload];
}

- (void)setMainWebViewController:(WebViewController *)mainWebViewController {
    _mainWebViewController = mainWebViewController;
    self.unreadCountObserver.webViewController = mainWebViewController;
}

- (UnreadCountObserver *)unreadCountObserver {
    if (_unreadCountObserver == nil) {
        _unreadCountObserver = [UnreadCountObserver new];
    }
    return _unreadCountObserver;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        AutomaticUpdateChecksKey: @YES,
        ShouldShowUnreadMailIndicatorKey: @YES,
        ShouldShowUnreadMailInDockKey: @YES,
        ShouldShowUnreadMailCountInDockKey: @YES,
        ShouldUseFastmailBetaKey: @NO,
        ShouldUseTransparentTitleBarKey: @YES,
    }];

    [self performAutomaticUpdateCheckIfNeeded];
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

- (IBAction)print:(id)sender {
    [[PrintManager sharedInstance] printWebView:self.mainWebViewController.webView];
}

- (void)setStatusItemVisible:(BOOL)visible {
    if (visible) {
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
    if (![NSUserDefaults.standardUserDefaults boolForKey:AutomaticUpdateChecksKey]) {
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
            [NSUserDefaults.standardUserDefaults setBool:NO forKey:AutomaticUpdateChecksKey];
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

- (void)createUserScriptsFolderIfNeeded {
    NSString *userScriptsFolderPath = [NSHomeDirectory() stringByAppendingPathComponent:@"userscripts"];
    BOOL folderExists = NO;
    [NSFileManager.defaultManager fileExistsAtPath:userScriptsFolderPath isDirectory:&folderExists];

    if (folderExists) {
        return;
    }

    [NSFileManager.defaultManager createDirectoryAtPath:userScriptsFolderPath withIntermediateDirectories:NO attributes:nil error:nil];
    [self addUserScriptsREADMEInFolder:userScriptsFolderPath];
}

- (void)addUserScriptsREADMEInFolder:(NSString *)folderPath {
    NSString *readmeFilePath = [folderPath stringByAppendingPathComponent:@"README.txt"];

    NSString *text = @""
    "Fastmate user scripts\n\n"
    "Put JavaScript files in this folder (.js), and Fastmate will load them at document end after loading the Fastmail website.\n";
    [NSFileManager.defaultManager createFileAtPath:readmeFilePath contents:[text dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
}

#pragma mark - NSUserNotificationCenterDelegate

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    [self.mainWebViewController handleNotificationClickWithIdentifier:notification.identifier];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler API_AVAILABLE(macos(10.14)) {
    NSString *identifier = response.notification.request.identifier;
    [self.mainWebViewController handleNotificationClickWithIdentifier:identifier];
    completionHandler();
}

@end

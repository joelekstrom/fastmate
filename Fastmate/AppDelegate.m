#import "AppDelegate.h"
#import "UnreadCountObserver.h"
#import "NotificationCenter.h"
#import "WebViewController.h"
#import "KVOBlockObserver.h"
#import "UserDefaultsKeys.h"
#import "VersionChecker.h"
#import "PrintManager.h"

@interface AppDelegate () <VersionCheckerDelegate, NotificationCenterDelegate>

@property (nonatomic, strong) UnreadCountObserver *unreadCountObserver;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, assign) BOOL isAutomaticUpdateCheck;
@property (nonatomic, strong) id statusBarIconObserver;

@end

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {

    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(workspaceDidWake:) name:NSWorkspaceDidWakeNotification object:NULL];

    self.statusBarIconObserver = [KVOBlockObserver observeUserDefaultsKey:ShouldShowStatusBarIconKey block:^(BOOL visible) {
        [self setStatusItemVisible:visible];
    }];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self createUserScriptsFolderIfNeeded];
    });

    NotificationCenter.sharedInstance.delegate = self;
    [NotificationCenter.sharedInstance registerForNotifications];
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

- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls {
    NSURL *URL = urls.firstObject;
    if ([URL.scheme isEqualToString:@"fastmate"]) {
        [self.mainWebViewController handleFastmateURL:URL];
    } else if ([URL.scheme isEqualToString:@"mailto"]) {
        [self.mainWebViewController handleMailtoURL:URL];
    }
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
    alert.suppressionButton.title = @"Check for new versions automatically";
    alert.suppressionButton.state = NSControlStateValueOn;
    [alert beginSheetModalForWindow:self.mainWebViewController.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [NSWorkspace.sharedWorkspace openURL:latestVersionURL];
        }

        if (alert.suppressionButton.state == NSOffState) {
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

#pragma mark - NotificationCenterDelegate

- (void)notificationCenter:(NotificationCenter *)center notificationClickedWithIdentifier:(NSString *)identifier {
    [self.mainWebViewController handleNotificationClickWithIdentifier:identifier];
}

@end

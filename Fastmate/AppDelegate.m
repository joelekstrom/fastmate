#import "AppDelegate.h"
#import "UnreadCountObserver.h"
#import "NotificationCenter.h"
#import "WebViewController.h"
#import "KVOBlockObserver.h"
#import "UserDefaultsKeys.h"
#import "PrintManager.h"
#import "Fastmate-Swift.h"

@interface AppDelegate () <NotificationCenterDelegate>

@property (nonatomic, strong) UnreadCountObserver *unreadCountObserver;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, assign) BOOL isAutomaticUpdateCheck;
@property (nonatomic, strong) id statusBarIconObserver;

// Temporary forwards app delegate methods to this object as they are migrated to swift
@property (nonatomic, strong) FastmateAppDelegate *forwardingSwiftDelegate;

@end

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.forwardingSwiftDelegate = [[FastmateAppDelegate alloc] init];
    [self.forwardingSwiftDelegate applicationDidFinishLaunching:notification];

    [NSAppleEventManager.sharedAppleEventManager setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];

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

- (IBAction)checkForUpdates:(id)sender {
    [self.forwardingSwiftDelegate checkForUpdatesWithSender:sender];
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

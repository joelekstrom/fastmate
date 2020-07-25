#import "AppDelegate.h"
#import "NotificationCenter.h"
#import "WebViewController.h"
#import "KVOBlockObserver.h"
#import "UserDefaultsKeys.h"
#import "PrintManager.h"
#import "Fastmate-Swift.h"

@interface AppDelegate () <NotificationCenterDelegate>

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, assign) BOOL isAutomaticUpdateCheck;

// Temporary forwards app delegate methods to this object as they are migrated to swift
@property (nonatomic, strong) FastmateAppDelegate *forwardingSwiftDelegate;

@end

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.forwardingSwiftDelegate = [FastmateAppDelegate sharedInstance];
    [self.forwardingSwiftDelegate applicationDidFinishLaunching:notification];

    [NSAppleEventManager.sharedAppleEventManager setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];

    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(workspaceDidWake:) name:NSWorkspaceDidWakeNotification object:NULL];

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

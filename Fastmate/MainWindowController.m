#import "MainWindowController.h"
#import "WebViewController.h"
#import "KVOBlockObserver.h"
#import "UserDefaultsKeys.h"
#import "Fastmate-Swift.h"

@interface MainWindowController () <NSWindowDelegate>

@property (nonatomic, strong) id titleBarSettingObserver;
@property (nonatomic, strong) id titleObserver;

@end

@implementation MainWindowController

- (void)windowDidLoad {
    [super windowDidLoad];

    // Fixes that we can't trust that the main window exists in applicationDidFinishLaunching:.
    // Here we always know that this content view controller will be the main web view controller,
    // so inform the app delegate
    AppDelegate *appDelegate = (AppDelegate *)NSApplication.sharedApplication.delegate;
    appDelegate.mainWebViewController = (WebViewController *)self.contentViewController;

    NSColor *windowColor = [NSKeyedUnarchiver unarchiveObjectWithData:[NSUserDefaults.standardUserDefaults dataForKey:WindowBackgroundColorKey]];
    self.window.backgroundColor = windowColor ?: [NSColor colorWithRed:0.27 green:0.34 blue:0.49 alpha:1.0];

    NSString *lastWindowFrame = [NSUserDefaults.standardUserDefaults objectForKey:MainWindowFrameKey];
    if (lastWindowFrame) {
        NSRect frame = NSRectFromString(lastWindowFrame);
        [self.window setFrame:frame display:NO];
    }

    __weak typeof(self) weakSelf = self;
    self.titleBarSettingObserver = [KVOBlockObserver observeUserDefaultsKey:ShouldUseTransparentTitleBarKey block:^(BOOL transparent) {
        weakSelf.window.titlebarAppearsTransparent = transparent;
        weakSelf.window.titleVisibility = transparent ? NSWindowTitleHidden : NSWindowTitleVisible;
    }];

    self.titleObserver = [KVOBlockObserver observe:self keyPath:@"contentViewController.webView.title" block:^(id  _Nonnull value) {
        if ([value isKindOfClass:NSString.class]) {
            weakSelf.window.title = value;
        }
    }];
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    [NSApp hide:sender];
    return NO;
}

- (void)windowDidResize:(NSNotification *)notification {
    if (self.windowLoaded) {
        [NSUserDefaults.standardUserDefaults setObject:NSStringFromRect(self.window.frame) forKey:MainWindowFrameKey];
    }
}

@end

#import "MainWindowController.h"
#import "WebViewController.h"
#import "AppDelegate.h"

@interface MainWindowController () <NSWindowDelegate>

@end

@implementation MainWindowController

- (void)windowDidLoad {
    [super windowDidLoad];

    // Fixes that we can't trust that the main window exists in applicationDidFinishLaunching:.
    // Here we always know that this content view controller will be the main web view controller,
    // so inform the app delegate
    AppDelegate *appDelegate = (AppDelegate *)NSApplication.sharedApplication.delegate;
    appDelegate.mainWebViewController = (WebViewController *)self.contentViewController;
    NSString *lastWindowFrame = [NSUserDefaults.standardUserDefaults objectForKey:@"mainWindowFrame"];
    if (lastWindowFrame) {
        NSRect frame = NSRectFromString(lastWindowFrame);
        [self.window setFrame:frame display:NO];
    }
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    [NSApp hide:sender];
    return NO;
}

- (void)windowDidResize:(NSNotification *)notification {
    if (self.windowLoaded) {
        [NSUserDefaults.standardUserDefaults setObject:NSStringFromRect(self.window.frame) forKey:@"mainWindowFrame"];
    }
}

@end

#import "MainWindowController.h"

@interface MainWindowController () <NSWindowDelegate>

@end

@implementation MainWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
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

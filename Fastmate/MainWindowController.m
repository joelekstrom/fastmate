#import "MainWindowController.h"

@interface MainWindowController () <NSWindowDelegate>

@end

@implementation MainWindowController

- (BOOL)windowShouldClose:(NSWindow *)sender {
    [NSApp hide:sender];
    return NO;
}

@end

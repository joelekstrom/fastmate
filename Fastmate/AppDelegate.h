#import <Cocoa/Cocoa.h>

@class WebViewController, FastmateAppDelegate;
@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) WebViewController *mainWebViewController;

// Temporary forwards app delegate methods to this object as they are migrated to swift
@property (nonatomic, readonly) FastmateAppDelegate *forwardingSwiftDelegate;

@end


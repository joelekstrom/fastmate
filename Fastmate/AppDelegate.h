#import <Cocoa/Cocoa.h>

@class WebViewController;
@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) WebViewController *mainWebViewController;

/// returns YES if the delegate handled the key, NO if it needs to be forwarded on
- (BOOL)handleKey:(NSEvent *)event;
@end


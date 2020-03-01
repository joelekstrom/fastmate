#import <Cocoa/Cocoa.h>

@class WKWebView;

@interface WebViewController : NSViewController

@property (nonatomic, readonly) WKWebView *webView;

- (void)composeNewEmail;
- (void)focusSearchField;
- (void)handleMailtoURL:(NSURL *)URL;
- (void)handleNotificationClickWithIdentifier:(NSString *)identifier;
- (void)reload;

@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *mailboxes; // Name -> unreadCount

@end

#import <Cocoa/Cocoa.h>

@class WKWebView;

@interface WebViewController : NSViewController

@property (nonatomic, readonly) WKWebView *webView;

- (void)composeNewEmail;
- (void)focusSearchField;
- (BOOL)deleteMessage;
- (BOOL)nextMessage;
- (BOOL)previousMessage;
- (void)handleMailtoURL:(NSURL *)URL;
- (void)handleFastmateURL:(NSURL *)URL;
- (void)handleNotificationClickWithIdentifier:(NSString *)identifier;
- (void)reload;

@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *mailboxes; // Name -> unreadCount
@property (nonatomic, strong) NSURL *currentlyViewedAttachment;

@end

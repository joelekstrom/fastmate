#import <Cocoa/Cocoa.h>

@class WKWebView;

NS_ASSUME_NONNULL_BEGIN

@interface WebViewController : NSViewController

@property (nonatomic, readonly, nullable) WKWebView *webView;

- (void)composeNewEmail;
- (void)focusSearchField;
- (void)handleMailtoURL:(NSURL *)URL;
- (void)handleNotificationClickWithIdentifier:(NSString *)identifier;
- (void)reload;

@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *mailboxes; // Name -> unreadCount

@end

NS_ASSUME_NONNULL_END

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class WKWebView, WKScriptMessage;

@interface WebViewController : NSViewController

@property (nonatomic, readonly, nullable) WKWebView *webView;

- (void)composeNewEmail;
- (void)focusSearchField;
- (BOOL)deleteMessage;
- (BOOL)nextMessage;
- (BOOL)previousMessage;
- (void)handleHttpsURL:(NSURL *)URL;
- (void)handleMailtoURL:(NSURL *)URL;
- (void)handleFastmateURL:(NSURL *)URL;
- (void)handleNotificationClickWithIdentifier:(NSString *)identifier;
- (void)reload;

@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *mailboxes; // Name -> unreadCount
@property (nonatomic, strong, nullable) NSURL *currentlyViewedAttachment;

@property (nonatomic, copy, nullable) void (^notificationHandler)(WKScriptMessage *);

@end

NS_ASSUME_NONNULL_END

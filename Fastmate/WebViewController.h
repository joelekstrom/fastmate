#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class WKWebView, WKScriptMessage;

@interface WebViewController : NSViewController

@property (nonatomic, readonly, nullable) WKWebView *webView;

- (void)setBaseURL:(NSURL *)baseURL;
- (void)composeNewEmail;
- (void)focusSearchField;
- (BOOL)deleteMessage;
- (BOOL)nextMessage;
- (BOOL)previousMessage;
- (void)handleNotificationClickWithIdentifier:(NSString *)identifier;
- (void)reload;

@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *mailboxes; // Name -> unreadCount
@property (nonatomic, strong, nullable) NSURL *currentlyViewedAttachment;

@property (nonatomic, copy, nullable) void (^notificationHandler)(WKScriptMessage *);

@end

NS_ASSUME_NONNULL_END

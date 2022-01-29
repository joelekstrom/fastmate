#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class WKWebView;

@interface WebViewController : NSViewController

@property (nonatomic, readonly, nullable) WKWebView *webView;

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
@property (nonatomic, strong, nullable) NSURL *currentlyViewedAttachment;

@end

NS_ASSUME_NONNULL_END

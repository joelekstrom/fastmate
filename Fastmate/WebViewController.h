#import <Cocoa/Cocoa.h>

@interface WebViewController : NSViewController

- (void)composeNewEmail;
- (void)focusSearchField;
- (void)handleMailtoURL:(NSURL *)URL;
- (void)handleNotificationClickWithIdentifier:(NSString *)identifier;

@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *mailboxes; // Name -> unreadCount

@end

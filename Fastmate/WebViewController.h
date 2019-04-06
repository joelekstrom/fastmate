#import <Cocoa/Cocoa.h>

@interface WebViewController : NSViewController

- (void)composeNewEmail;
- (void)focusSearchField;
- (void)handleMailtoURL:(NSURL *)URL;

@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *mailboxes; // Name -> unreadCount

@end

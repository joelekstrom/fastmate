#import <Foundation/Foundation.h>
#import "WebViewController.h"

@interface UnreadCountObserver : NSObject

@property (nonatomic, strong) WebViewController *webViewController;
@property (nonatomic, weak) NSStatusItem *statusItem;

@end

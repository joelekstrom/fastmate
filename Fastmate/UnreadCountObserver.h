#import <Foundation/Foundation.h>
#import "WebViewController.h"

@interface UnreadCountObserver : NSObject

- (instancetype)initWithWebViewController:(WebViewController *)controller;
@property (nonatomic, weak) NSStatusItem *statusItem;

@end

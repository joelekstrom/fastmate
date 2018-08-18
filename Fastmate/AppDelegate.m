#import "AppDelegate.h"
#import "WebViewController.h"

@interface AppDelegate ()

@property (nonatomic, strong) IBOutlet WebViewController *mainWebViewController;

@end

@implementation AppDelegate

- (IBAction)newDocument:(id)sender {
    [self.mainWebViewController composeNewEmail];
}

@end

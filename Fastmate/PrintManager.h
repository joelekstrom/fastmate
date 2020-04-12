#import <Foundation/Foundation.h>

@class WKWebView;

NS_ASSUME_NONNULL_BEGIN

/**
 A class to workaround the limitation of being unable to print
 from WKWebView. Instantiates a legacy WebView-object and
 forwards the print command to it.
 */
@interface PrintManager : NSObject

+ (instancetype)sharedInstance;
- (void)printWebView:(WKWebView *)webView;

@end

NS_ASSUME_NONNULL_END

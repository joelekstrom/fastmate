//
//  PrintController.h
//  Fastmate
//
//  Created by Joel Ekström on 2020-03-01.
//

#import <Foundation/Foundation.h>

@class WKWebView, PrintManager;

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

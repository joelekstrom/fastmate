//
//  PrintController.m
//  Fastmate
//
//  Created by Joel Ekström on 2020-03-01.
//

#import "PrintManager.h"
@import WebKit;

@interface PrintManager() <WebFrameLoadDelegate>

@property (nonatomic, strong) WebView *webView;
@property (nonatomic, strong) NSPrintInfo *printInfo;

@end

@implementation PrintManager

+ (instancetype)sharedInstance {
    static PrintManager *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [PrintManager new];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _printInfo = [NSPrintInfo sharedPrintInfo];
        _printInfo.topMargin = 25;
        _printInfo.bottomMargin = 10;
        _printInfo.rightMargin = 10;
        _printInfo.leftMargin = 10;
    }
    return self;
}

- (void)printWebView:(WKWebView *)sourceView {
    NSRect webViewFrame = NSMakeRect(0, 0, self.printInfo.paperSize.width, self.printInfo.paperSize.height);
    self.webView = [[WebView alloc] initWithFrame:webViewFrame frameName:@"printFrame" groupName:@"printGroup"];
    self.webView.shouldUpdateWhileOffscreen = true;
    self.webView.frameLoadDelegate = self;

    [sourceView evaluateJavaScript:@"document.documentElement.outerHTML.toString()"
                 completionHandler:^(NSString *HTML, NSError *error) {
        [self.webView.mainFrame loadHTMLString:HTML baseURL:NSBundle.mainBundle.resourceURL];
    }];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    if (frame != sender.mainFrame || sender.isLoading) {
        return;
    }

    if ([[sender stringByEvaluatingJavaScriptFromString:@"document.readyState"] isEqualToString:@"complete"]) {
        sender.frameLoadDelegate = nil;
        NSWindow *window = NSApp.mainWindow ?: NSApp.windows.firstObject;
        NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:frame.frameView.documentView printInfo:self.printInfo];
        [printOperation runOperationModalForWindow:window delegate:self didRunSelector:@selector(printOperationDidFinish) contextInfo:nil];
    }
}

- (void)printOperationDidFinish {
    self.webView = nil;
}

@end

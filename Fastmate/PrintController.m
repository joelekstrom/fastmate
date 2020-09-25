#import "PrintController.h"
@import WebKit;

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

@interface PrintController() <WebFrameLoadDelegate>

@property (nonatomic, weak) WKWebView *sourceView;
@property (nonatomic, strong) WebView *webView;
@property (nonatomic, strong) NSPrintInfo *printInfo;
@property (nonatomic, copy) NSString *emailTitle;

@end

@implementation PrintController

+ (instancetype)sharedInstance {
    static PrintController *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [PrintController new];
    });
    return sharedInstance;
}

- (instancetype)initWithWebView:(WKWebView *)webView {
    if (self = [super init]) {
        _sourceView = webView;
        _printInfo = [NSPrintInfo sharedPrintInfo];
        _printInfo.topMargin = 25;
        _printInfo.bottomMargin = 10;
        _printInfo.rightMargin = 10;
        _printInfo.leftMargin = 10;
    }
    return self;
}

- (void)print {
    NSRect webViewFrame = NSMakeRect(0, 0, self.printInfo.paperSize.width, self.printInfo.paperSize.height);
    self.webView = [[WebView alloc] initWithFrame:webViewFrame frameName:@"printFrame" groupName:@"printGroup"];
    self.webView.shouldUpdateWhileOffscreen = true;
    self.webView.frameLoadDelegate = self;

    // Get e-mail title to set default name of PDF
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"– (.*) \\| Fastmail" options:0 error:nil];
    NSTextCheckingResult *result = [regex firstMatchInString:self.sourceView.title options:0 range:NSMakeRange(0, self.sourceView.title.length)];
    if (result && result.numberOfRanges > 1) {
        self.emailTitle = [self.sourceView.title substringWithRange:[result rangeAtIndex:1]];
    }

    [self.sourceView evaluateJavaScript:@"document.documentElement.outerHTML.toString()"
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
        NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:frame.frameView.documentView printInfo:self.printInfo];
        printOperation.jobTitle = self.emailTitle;
        [printOperation runOperationModalForWindow:self.sourceView.window delegate:self didRunSelector:@selector(printOperationDidFinish) contextInfo:nil];
    }
}

- (void)printOperationDidFinish {
    self.webView = nil;
}

@end

#import "PrintManager.h"
@import WebKit;

@interface PrintManager() <WebFrameLoadDelegate, WebUIDelegate>

@property (nonatomic, strong) WebView *webView;
@property (nonatomic, strong) NSPrintInfo *printInfo;
@property (nonatomic, copy) NSString *headerTitle;
@property (nonatomic, copy) NSString *emailTitle;
@property (nonatomic, copy) NSURL *emailURL;
@property (nonatomic, weak) NSPrintOperation *currentOperation;

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
        _printInfo.topMargin = 0;
        _printInfo.bottomMargin = 0;
        _printInfo.rightMargin = 20;
        _printInfo.leftMargin = 20;
        _printInfo.printSettings[NSPrintHeaderAndFooter] = @(YES);
    }
    return self;
}

- (void)printWebView:(WKWebView *)sourceView {
    NSRect webViewFrame = NSMakeRect(0, 0, self.printInfo.paperSize.width, self.printInfo.paperSize.height);
    self.webView = [[WebView alloc] initWithFrame:webViewFrame frameName:@"printFrame" groupName:@"printGroup"];
    self.webView.shouldUpdateWhileOffscreen = true;
    self.webView.frameLoadDelegate = self;
    self.webView.UIDelegate = self;
    self.headerTitle = sourceView.title;
    self.emailURL = sourceView.URL;

    // Get e-mail title to set default name of PDF
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"– (.*) \\| Fastmail" options:0 error:nil];
    NSTextCheckingResult *result = [regex firstMatchInString:sourceView.title options:0 range:NSMakeRange(0, sourceView.title.length)];
    if (result && result.numberOfRanges > 1) {
        self.emailTitle = [sourceView.title substringWithRange:[result rangeAtIndex:1]];
    }

    [sourceView evaluateJavaScript:@"document.documentElement.outerHTML.toString()"
                 completionHandler:^(NSString *HTML, NSError *error) {
        [self.webView.mainFrame loadHTMLString:HTML baseURL:NSBundle.mainBundle.resourceURL];
    }];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    if (frame != sender.mainFrame || sender.isLoading) {
        return;
    }

    // Dispatch to fix a bug where document.readyState is never complete the first time after app launch
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([[sender stringByEvaluatingJavaScriptFromString:@"document.readyState"] isEqualToString:@"complete"]) {
            sender.frameLoadDelegate = nil;
            NSWindow *window = NSApp.mainWindow ?: NSApp.windows.firstObject;
            NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:frame.frameView.documentView printInfo:self.printInfo];
            printOperation.jobTitle = self.emailTitle;
            self.currentOperation = printOperation;
            [printOperation runOperationModalForWindow:window delegate:self didRunSelector:@selector(printOperationDidFinish) contextInfo:nil];
        }
    });
}

- (void)printOperationDidFinish {
    self.webView = nil;
}

- (float)webViewHeaderHeight:(WebView *)sender
{
    return 50.0;
}

- (void)webView:(WebView *)sender drawHeaderInRect:(NSRect)rect
{
    CGFloat verticalOffset = 20.0;
    NSDictionary *fontAttributes = @{NSFontAttributeName: [NSFont systemFontOfSize:7.0]};

    [self.headerTitle drawWithRect:CGRectOffset(rect, 0, verticalOffset) options:0 attributes:fontAttributes];

    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    dateFormatter.timeStyle = NSDateFormatterMediumStyle;
    NSString *dateString = [dateFormatter stringFromDate:NSDate.date];

    CGSize dateSize = [dateString sizeWithAttributes:fontAttributes];
    CGRect dateRect = CGRectMake(CGRectGetMaxX(rect) - dateSize.width, rect.origin.y + verticalOffset, dateSize.width, dateSize.height);

    [dateString drawWithRect:dateRect options:0 attributes:fontAttributes];
}

- (float)webViewFooterHeight:(WebView *)sender
{
    return 50.0;
}

- (void)webView:(WebView *)sender drawFooterInRect:(NSRect)rect
{
    CGFloat verticalOffset = 20.0;
    NSDictionary *fontAttributes = @{NSFontAttributeName: [NSFont systemFontOfSize:7.0]};
    [self.emailURL.absoluteString drawWithRect:CGRectOffset(rect, 0, verticalOffset) options:0 attributes:fontAttributes];

    NSString *currentPageString = [NSString stringWithFormat:@"Page %@ of %@", @(self.currentOperation.currentPage), @(self.currentOperation.pageRange.length)];
    CGSize pageSize = [currentPageString sizeWithAttributes:fontAttributes];
    CGRect pageRect = CGRectMake(CGRectGetMaxX(rect) - pageSize.width, rect.origin.y + verticalOffset, pageSize.width, pageSize.height);

    [currentPageString drawWithRect:pageRect options:0 attributes:fontAttributes];
}

@end

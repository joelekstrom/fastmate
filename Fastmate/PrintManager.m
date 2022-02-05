#import "PrintManager.h"
@import WebKit;
@import PDFKit;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

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

- (void)printControllerContent:(WebViewController *)controller {
    WKWebView *sourceView = controller.webView;

    // If current URL has 5 path components, assume we're viewing attachment. In this case we use WKWebView for print,
    // which will handle printing PDF properly. Otherwise fall back to legacy WebView to print. WKWebView printing
    // does not support headers and footers.
    if (sourceView.URL.pathComponents.count >= 5) {
        NSPrintOperation *printOperation = [self printOperationForWKWebView:sourceView];
        if (printOperation) {
            [self runPrintOperation:printOperation];
            return;
        }
    }

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

    if (controller.currentlyViewedAttachment && [controller.currentlyViewedAttachment.absoluteString containsString:@".pdf"]) {
        // If user is viewing a PDF attachment, we can print that directly
        [self printPDF:controller.currentlyViewedAttachment];
    } else {
        // Otherwise, take the HTML body and put it in the new web view
        [sourceView evaluateJavaScript:@"document.documentElement.outerHTML.toString()"
                     completionHandler:^(NSString *HTML, NSError *error) {
            [self.webView.mainFrame loadHTMLString:HTML baseURL:NSBundle.mainBundle.resourceURL];
        }];
    }

}

- (void)printPDF:(NSURL *)pdfURL
{
    PDFDocument *document = [[PDFDocument alloc] initWithURL:pdfURL];
    NSPrintOperation *printOperation = [document printOperationForPrintInfo:_printInfo scalingMode:kPDFPrintPageScaleToFit autoRotate:YES];
    [self runPrintOperation:printOperation];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    if (frame != sender.mainFrame || sender.isLoading) {
        return;
    }

    // Dispatch to fix a bug where document.readyState is never complete the first time after app launch
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([[sender stringByEvaluatingJavaScriptFromString:@"document.readyState"] isEqualToString:@"complete"]) {
            sender.frameLoadDelegate = nil;
            NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:frame.frameView.documentView printInfo:self.printInfo];
            [self runPrintOperation:printOperation];
        }
    });
}

- (void)runPrintOperation:(NSPrintOperation *)printOperation
{
    printOperation.jobTitle = self.emailTitle;
    printOperation.showsPrintPanel = YES;
    printOperation.showsProgressPanel = YES;
    self.currentOperation = printOperation;
    NSWindow *window = NSApp.mainWindow ?: NSApp.windows.firstObject;
    [printOperation runOperationModalForWindow:window delegate:self didRunSelector:@selector(printOperationDidFinish) contextInfo:nil];
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

- (NSPrintOperation *)printOperationForWKWebView:(WKWebView *)webView
{
    NSPrintOperation *operation = nil;
    if (@available(macOS 11.0, *)) {
        operation = [webView printOperationWithPrintInfo:_printInfo];
    } else {
        SEL printSelector = NSSelectorFromString(@"_printOperationWithPrintInfo:");
        if ([webView respondsToSelector:printSelector]) {
            IMP imp = [webView methodForSelector:printSelector];
            NSPrintOperation *(*func)(id, SEL, NSPrintInfo *) = (void *)imp;
            operation = func(webView, printSelector, _printInfo);
        }
    }
    operation.view.frame = webView.bounds;
    return operation;
}

@end

#pragma clang diagnostic pop

#import "WebViewController.h"
#import "UserDefaultsKeys.h"
#import "PrintManager.h"
#import "FileDownloadManager.h"
@import WebKit;

@interface WKWebView (SyncBridge)
- (BOOL)evaluateJavaScript:(NSString *)script;
@end

@interface WebViewController () <WKNavigationDelegate, WKScriptMessageHandler>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) WebViewDelegate *uiDelegate;
@property (nonatomic, strong) WKUserContentController *userContentController;
@property (nonatomic, strong) id currentURLObserver;
@property (nonatomic, strong) FileDownloadManager *fileDownloadManager;
@property (nonatomic, strong) NSURL *baseURL;
@property (nonatomic, strong) NSTextField *linkPreviewTextField;
@property (nonatomic, assign) CGFloat zoomLevel;


// If the user is for example viewing a PDF inline, this value will point to the actual file
@property (nonatomic, strong) NSURL *lastViewedUserContent;

@end

@implementation WebViewController

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        _mailboxes = @{};
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configureUserContentController];
    _zoomLevel = 1.0;

    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    configuration.applicationNameForUserAgent = @"Fastmate";
    configuration.userContentController = self.userContentController;
    [configuration.preferences setValue:@YES forKey:@"developerExtrasEnabled"];

    WKWebView *webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
    webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    webView.navigationDelegate = self;
    [self.view addSubview:webView];
    self.webView = webView;

    self.uiDelegate = [[WebViewDelegate alloc] init];
    self.uiDelegate.requestHandler = ^(NSURLRequest *request) {
        [webView loadRequest:request];
    };
    webView.UIDelegate = self.uiDelegate;

    [webView addObserver:self forKeyPath:@"URL" options:NSKeyValueObservingOptionNew context:nil];
    self.fileDownloadManager = [[FileDownloadManager alloc] init];
}

- (void)dealloc
{
    [self.webView removeObserver:self forKeyPath:@"URL"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == self.webView && [keyPath isEqualToString:@"URL"]) {
        [self queryToolbarColor];
        [self adjustV67Width];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)setBaseURL:(NSURL *)baseURL
{
    _baseURL = baseURL;
    NSURL *mailURL = [baseURL URLByAppendingPathComponent:@"mail" isDirectory:YES];
    [self.webView loadRequest:[NSURLRequest requestWithURL:mailURL]];
}

- (NSURL *)currentlyViewedAttachment
{
    NSString *attachmentID = [[self.webView.URL.lastPathComponent componentsSeparatedByString:@"."] lastObject];
    if ([self.lastViewedUserContent.absoluteString containsString:attachmentID]) {
        return self.lastViewedUserContent;
    }
    return nil;
}

- (void)reload {
    [self.webView reload];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    self.lastViewedUserContent = nil;
    
    if ([navigationAction.request.URL.host hasSuffix:@".fastmailusercontent.com"]) {
        if ([self isDownloadRequest:navigationAction.request]) {
            [self.fileDownloadManager addDownloadWithURL:navigationAction.request.URL];
            decisionHandler(WKNavigationActionPolicyCancel);
        } else {
            self.lastViewedUserContent = navigationAction.request.URL;
            decisionHandler(WKNavigationActionPolicyAllow);
        }
    } else if ([navigationAction.request.URL.host hasSuffix:@".fastmail.com"]) {
        decisionHandler(WKNavigationActionPolicyAllow);
    } else {
        // Link isn't within fastmail.com, open externally
        if (@available(macOS 10.15, *)) {
            NSWorkspaceOpenConfiguration *configuration = NSWorkspaceOpenConfiguration.configuration;
            configuration.activates = (navigationAction.modifierFlags && NSEventModifierFlagCommand) == 0;
            [NSWorkspace.sharedWorkspace openURL:navigationAction.request.URL configuration:configuration completionHandler:nil];
        } else {
            // Fallback on earlier versions
            [NSWorkspace.sharedWorkspace openURL:navigationAction.request.URL];
        }
        decisionHandler(WKNavigationActionPolicyCancel);
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler{
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)navigationResponse.response;
    NSArray *cookies =[NSHTTPCookie cookiesWithResponseHeaderFields:[response allHeaderFields] forURL:response.URL];

    for (NSHTTPCookie *cookie in cookies) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
    }

    decisionHandler(WKNavigationResponsePolicyAllow);
}

/**
 YES if request is to download a fastmail-hosted file
 */
- (BOOL)isDownloadRequest:(NSURLRequest *)request
{
    NSURLComponents *components = [NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
    BOOL hasDownloadQueryItem = [components.queryItems indexOfObjectPassingTest:^BOOL(NSURLQueryItem *item, NSUInteger index, BOOL *stop) {
        return [item.name isEqualToString:@"download"] && [item.value isEqualToString:@"1"];
    }] != NSNotFound;

    if (hasDownloadQueryItem) {
        return YES;
    }

    // We want to display PDF's inline if it wasn't a specific request for download
    if ([components.path hasSuffix:@".pdf"]) {
        return NO;
    }

    return [components.path hasPrefix:@"/jmap/download/"];
}

- (void)composeNewEmail {
    [self.webView evaluateJavaScript:@"Fastmate.compose()" completionHandler:nil];
}

- (void)focusSearchField {
    [self.webView evaluateJavaScript:@"Fastmate.focusSearch()" completionHandler:nil];
}

- (BOOL)nextMessage {
    return [self.webView evaluateJavaScript:@"Fastmate.nextMessage()"];
}

- (BOOL)previousMessage {
    return [self.webView evaluateJavaScript:@"Fastmate.previousMessage()"];
}

- (void)queryToolbarColor {
    [self.webView evaluateJavaScript:@"Fastmate.getToolbarColor()" completionHandler:^(id response, NSError *error) {
        NSString *colorString = [response isKindOfClass:NSString.class] ? response : nil;
        if (colorString) {
            colorString = [colorString stringByReplacingOccurrencesOfString:@"rgb(" withString:@""];
            colorString = [colorString stringByReplacingOccurrencesOfString:@")" withString:@""];
            NSArray<NSString *> *components = [colorString componentsSeparatedByString:@","];
            NSInteger red = components[0].integerValue;
            NSInteger green = components[1].integerValue;
            NSInteger blue = components[2].integerValue;
            NSColor *color = [NSColor colorWithRed:red / 255.0 green:green / 255.0 blue:blue / 255.0 alpha:1.0];
            [self setWindowBackgroundColor:color];
        }
    }];
}

- (void)updateUnreadCounts {
    [self.webView evaluateJavaScript:@"Fastmate.getMailboxUnreadCounts()" completionHandler:^(id response, NSError *error) {
        if ([response isKindOfClass:NSDictionary.class]) {
            self.mailboxes = response;
        } else {
            self.mailboxes = @{};
        }
    }];
}

- (void)setWindowBackgroundColor:(NSColor *)color {
    NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color requiringSecureCoding:YES error:nil];
    [NSUserDefaults.standardUserDefaults setObject:colorData forKey:WindowBackgroundColorKey];
    self.view.window.backgroundColor = color;
}

- (void)configureUserContentController {
    self.userContentController = [WKUserContentController new];
    [self.userContentController addScriptMessageHandler:self name:@"Notification"];
    [self.userContentController addScriptMessageHandler:self name:@"LinkHover"];
    [self.userContentController addScriptMessageHandler:self name:@"DocumentDidChange"];
    [self.userContentController addScriptMessageHandler:self name:@"Print"];

    NSString *fastmateSource = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"Fastmate" withExtension:@"js"] encoding:NSUTF8StringEncoding error:nil];
    WKUserScript *fastmateScript = [[WKUserScript alloc] initWithSource:fastmateSource injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    [self.userContentController addUserScript:fastmateScript];

    [self loadUserScripts];
    [self loadUserStyles];
}

- (void)loadUserScripts {
    NSString *userScriptsDirectoryPath = [NSHomeDirectory() stringByAppendingPathComponent:@"userscripts"];
    NSDirectoryEnumerator<NSString *> *enumerator = [NSFileManager.defaultManager enumeratorAtPath:userScriptsDirectoryPath];
    for (NSString *fileName in enumerator) {
        if (![fileName.pathExtension isEqualToString:@"js"]) {
            continue;
        }

        NSString *scriptContent = [NSString stringWithContentsOfFile:[userScriptsDirectoryPath stringByAppendingPathComponent:fileName] encoding:NSUTF8StringEncoding error:nil];
        WKUserScript *script = [[WKUserScript alloc] initWithSource:scriptContent injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
        [self.userContentController addUserScript:script];
    }
}

- (void)loadUserStyles {
    NSString *userStylesDirectoryPath = [NSHomeDirectory() stringByAppendingPathComponent:@"userstyles"];
    NSDirectoryEnumerator<NSString *> *enumerator = [NSFileManager.defaultManager enumeratorAtPath:userStylesDirectoryPath];
    for (NSString *fileName in enumerator) {
        if (![fileName.pathExtension isEqualToString:@"css"]) {
            continue;
        }

        NSString *cssContent = [NSString stringWithContentsOfFile:[userStylesDirectoryPath stringByAppendingPathComponent:fileName] encoding:NSUTF8StringEncoding error:nil];
        NSString *scriptContent = [NSString stringWithFormat:@"javascript:(function() { var parent = document.getElementsByTagName('head').item(0); var style = document.createElement('style'); style.type = 'text/css'; style.innerHTML = `%@`; parent.appendChild(style); })();", cssContent];
        WKUserScript *script = [[WKUserScript alloc] initWithSource:scriptContent injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
        [self.userContentController addUserScript:script];
    }
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"Notification"]) {
        [self postNotificationForMessage:message];
    } else if ([message.name isEqualToString:@"LinkHover"]) {
        [self handleLinkHoverMessage:message];
    } else if ([message.name isEqualToString:@"DocumentDidChange"]) {
        [self queryToolbarColor];
        [self updateUnreadCounts];

        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            self.zoomLevel = [NSUserDefaults.standardUserDefaults doubleForKey:NSStringFromSelector(@selector(zoomLevel))];
        });
    } else if ([message.name isEqualToString:@"Print"]) {
        [PrintManager.sharedInstance printControllerContent:self];
    }
}

- (void)handleLinkHoverMessage:(WKScriptMessage *)message {
    if ([message.body isKindOfClass:NSString.class]) {
        self.linkPreviewTextField.stringValue = [NSString stringWithFormat:@" %@ ", message.body];
        self.linkPreviewTextField.hidden = NO;
        self.linkPreviewTextField.layer.zPosition = 10;
    } else {
        self.linkPreviewTextField.hidden = YES;
    }
}

- (IBAction)copyLinkToCurrentItem:(id)sender {
    [self copyURLToPasteboard:self.webView.URL];
}

- (IBAction)copyFastmateLinkToCurrentItem:(id)sender {
    NSURLComponents *components = [NSURLComponents componentsWithURL:self.webView.URL resolvingAgainstBaseURL:YES];
    components.scheme = @"fastmate";
    components.host = @"app";
    [self copyURLToPasteboard:components.URL];
}

- (IBAction)zoomIn:(id)sender {
    self.zoomLevel += 0.1;
}

- (IBAction)zoomOut:(id)sender {
    self.zoomLevel -= 0.1;
}

- (IBAction)resetZoomLevel:(id)sender {
    self.zoomLevel = 1.0;
}

- (void)setZoomLevel:(CGFloat)zoomLevel {
    _zoomLevel = zoomLevel;
    [self.webView evaluateJavaScript:[NSString stringWithFormat:@"document.body.style.zoom = %f;", self.zoomLevel]];
    [NSUserDefaults.standardUserDefaults setDouble:zoomLevel forKey:NSStringFromSelector(@selector(zoomLevel))];
}

- (void)copyURLToPasteboard:(NSURL *)URL {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard writeObjects:@[URL, URL.absoluteString]];
    NSString *title = [[self.webView.title componentsSeparatedByString:@" – "] lastObject];
    [pasteboard setString:title forType:@"net.shinyfrog.bear.url-name"]; // Bear Notes title
    if ([URL.scheme isEqualToString:@"https"]) {
        [pasteboard setString:title forType:@"public.url-name"]; // Chromium title
    }
}

- (void)postNotificationForMessage:(WKScriptMessage *)message {
    if (self.notificationHandler) {
        self.notificationHandler(message);
    }
}

- (void)handleNotificationClickWithIdentifier:(NSString *)identifier {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.webView evaluateJavaScript:[NSString stringWithFormat:@"Fastmate.handleNotificationClick(\"%@\")", identifier] completionHandler:nil];
    });
}

- (void)adjustV67Width {
    [self.webView evaluateJavaScript:@"Fastmate.adjustV67Width()" completionHandler:nil];
}

- (NSTextField *)linkPreviewTextField {
    if (!_linkPreviewTextField) {
        _linkPreviewTextField = [NSTextField labelWithString:@""];
        _linkPreviewTextField.wantsLayer = YES;
        _linkPreviewTextField.drawsBackground = NO;

        _linkPreviewTextField.layer.backgroundColor = [NSColor.darkGrayColor colorWithAlphaComponent:0.8].CGColor;
        _linkPreviewTextField.layer.borderColor = [NSColor.whiteColor colorWithAlphaComponent:0.65].CGColor;
        _linkPreviewTextField.layer.borderWidth = 1;
        _linkPreviewTextField.layer.cornerRadius = 3.5;
        _linkPreviewTextField.textColor = [NSColor whiteColor];
        _linkPreviewTextField.translatesAutoresizingMaskIntoConstraints = NO;
        _linkPreviewTextField.cell.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [_linkPreviewTextField setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self.view addSubview:_linkPreviewTextField];
        [_linkPreviewTextField.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor multiplier:0.75].active = YES;
        [self.view.rightAnchor constraintEqualToAnchor:_linkPreviewTextField.rightAnchor constant:4].active = YES;
        [self.view.bottomAnchor constraintEqualToAnchor:_linkPreviewTextField.bottomAnchor constant:2].active = YES;
    }
    return _linkPreviewTextField;
}

@end

// based on code found in this answer:
// https://stackoverflow.com/a/68434118

@implementation WKWebView (SyncBridge)
- (BOOL)evaluateJavaScript:(NSString *)script {
    BOOL __block waiting = YES;
    id __block retVal = nil;
    [self evaluateJavaScript: script completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        if (error == nil) {
            retVal = result;
        }
        waiting = NO;
    }];
    
    while (waiting) {
        [NSRunLoop.currentRunLoop acceptInputForMode:NSDefaultRunLoopMode beforeDate:NSDate.distantFuture];
    }
    return [retVal isEqual:@YES];
}
@end


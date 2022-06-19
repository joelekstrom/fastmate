#import "WebViewController.h"
#import "KVOBlockObserver.h"
#import "UserDefaultsKeys.h"
#import "PrintManager.h"
@import WebKit;

@interface WKWebView (SyncBridge)
- (BOOL)evaluateJavaScript:(NSString *)script;
@end

@interface WebViewController () <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) WKWebView *temporaryWebView;
@property (nonatomic, strong) WKUserContentController *userContentController;
@property (nonatomic, strong) ComposeWindowController *composeWindowController;
@property (nonatomic, strong) id baseURLObserver;
@property (nonatomic, strong) id currentURLObserver;
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
    self.zoomLevel = 1.0;

    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    configuration.applicationNameForUserAgent = @"Fastmate";
    configuration.userContentController = self.userContentController;
    [configuration.preferences setValue:@YES forKey:@"developerExtrasEnabled"];

    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
    self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    [self.view addSubview:self.webView];

    __weak typeof(self) weakSelf = self;
    self.currentURLObserver = [KVOBlockObserver observe:self keyPath:@"webView.URL" block:^(id _Nonnull value) {
        [weakSelf queryToolbarColor];
        [weakSelf adjustV67Width];
    }];

    self.baseURLObserver = [KVOBlockObserver observeUserDefaultsKey:ShouldUseFastmailBetaKey block:^(BOOL useBeta) {
        NSString *baseURLString = useBeta ? @"https://beta.fastmail.com" : @"https://www.fastmail.com";
        weakSelf.baseURL = [NSURL URLWithString:baseURLString];
        NSURL *mailURL = [weakSelf.baseURL URLByAppendingPathComponent:@"mail" isDirectory:YES];
        [weakSelf.webView loadRequest:[NSURLRequest requestWithURL:mailURL]];
    }];
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
    BOOL isFastmailLink = [navigationAction.request.URL.host hasSuffix:@".fastmail.com"];
    self.lastViewedUserContent = nil;

    if (webView == self.temporaryWebView) {
        // A temporary web view means we caught a link URL which Fastmail wants to open externally (like a new tab).
        // However, if  it's a user-added link to an e-mail, prefer to open it within Fastmate itself
        BOOL isEmailLink = isFastmailLink && [navigationAction.request.URL.path hasPrefix:@"/mail/"];
        if (isEmailLink) {
            [self.webView loadRequest:[NSURLRequest requestWithURL:navigationAction.request.URL]];
        } else {
            [NSWorkspace.sharedWorkspace openURL:navigationAction.request.URL];
        }
        decisionHandler(WKNavigationActionPolicyCancel);
        self.temporaryWebView = nil;
    } else if ([navigationAction.request.URL.host hasSuffix:@".fastmailusercontent.com"]) {
        if ([self isDownloadRequest:navigationAction.request]) {
            [NSWorkspace.sharedWorkspace openURL:navigationAction.request.URL];
            decisionHandler(WKNavigationActionPolicyCancel);
        } else {
            self.lastViewedUserContent = navigationAction.request.URL;
            decisionHandler(WKNavigationActionPolicyAllow);
        }
    } else if (isFastmailLink) {
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

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    self.temporaryWebView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    self.temporaryWebView.navigationDelegate = self;
    return self.temporaryWebView;
}

- (BOOL)composeNewEmail {
    return [self.webView evaluateJavaScript:@"Fastmate.composeNewEmail()"];
}

- (BOOL)deleteMessage {
    return [self.webView evaluateJavaScript:@"Fastmate.deleteMessage()"];
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

- (void)handleMailtoURL:(NSURL *)URL {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:self.baseURL resolvingAgainstBaseURL:NO];
    components.path = @"/action/compose/";
    NSString *mailtoString = [URL.absoluteString stringByReplacingOccurrencesOfString:@"mailto:" withString:@""];
    components.percentEncodedQueryItems = @[[NSURLQueryItem queryItemWithName:@"mailto" value:mailtoString]];
    NSURL *actionURL = components.URL;
    [self.webView loadRequest:[NSURLRequest requestWithURL:actionURL]];
}

- (void)handleFastmateURL:(NSURL *)URL {
    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    components.scheme = @"https";
    components.host = self.baseURL.host;
    [self.webView loadRequest:[NSURLRequest requestWithURL:components.URL]];
}

- (void)configureUserContentController {
    self.userContentController = [WKUserContentController new];
    [self.userContentController addScriptMessageHandler:self name:@"Notification"];
    [self.userContentController addScriptMessageHandler:self name:@"LinkHover"];
    [self.userContentController addScriptMessageHandler:self name:@"DocumentDidChange"];
    [self.userContentController addScriptMessageHandler:self name:@"Print"];
    [self.userContentController addScriptMessageHandler:self name:@"OpenComposeWindow"];

    NSString *fastmateSource = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"Fastmate" withExtension:@"js"] encoding:NSUTF8StringEncoding error:nil];
    WKUserScript *fastmateScript = [[WKUserScript alloc] initWithSource:fastmateSource injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    [self.userContentController addUserScript:fastmateScript];

    [self loadUserScripts];
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

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"Notification"]) {
        [self postNotificationForMessage:message];
    } else if ([message.name isEqualToString:@"LinkHover"]) {
        [self handleLinkHoverMessage:message];
    } else if ([message.name isEqualToString:@"DocumentDidChange"]) {
        [self queryToolbarColor];
        [self updateUnreadCounts];
    } else if ([message.name isEqualToString:@"Print"]) {
        [PrintManager.sharedInstance printControllerContent:self];
    } else if ([message.name isEqualToString:@"OpenComposeWindow"]) {
        AppDelegate *appDelegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
        [appDelegate openComposeWindow];
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

- (void)webView:(WKWebView *)webView runOpenPanelWithParameters:(WKOpenPanelParameters *)parameters initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSArray<NSURL *> *URLs))completionHandler {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    if (@available(macOS 10.13.4, *)) {
        panel.canChooseDirectories = parameters.allowsDirectories;
    } else {
        panel.canChooseDirectories = NO;
    }
    panel.allowsMultipleSelection = parameters.allowsMultipleSelection;
    panel.canCreateDirectories = NO;
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        completionHandler(result == NSModalResponseOK ? panel.URLs : nil);
    }];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    NSAlert *alert = [NSAlert new];
    alert.messageText = message;
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleInformational;
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        completionHandler(returnCode == NSAlertFirstButtonReturn);
    }];
}

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    NSAlert *alert = [NSAlert new];
    alert.messageText = message;
    [alert addButtonWithTitle:@"OK"];
    alert.alertStyle = NSAlertStyleInformational;
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        completionHandler();
    }];
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString *))completionHandler {
    NSAlert *alert = [NSAlert new];
    alert.messageText = prompt;
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleInformational;
    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    textField.stringValue = defaultText;
    [alert setAccessoryView:textField];
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        completionHandler(returnCode == NSAlertFirstButtonReturn ? textField.stringValue : defaultText);
    }];
}

- (void)adjustV67Width {
    [self.webView evaluateJavaScript:@"Fastmate.adjustV67Width()" completionHandler:nil];
}

- (void)hideSidebar {
    [self.webView evaluateJavaScript:@"Fastmate.hideSidebar()" completionHandler:nil];
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

@implementation ComposeWebViewController

- (void)viewDidLoad {
    [super configureUserContentController];
    self.zoomLevel = 1.0;

    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    configuration.applicationNameForUserAgent = @"Fastmate compose";
    configuration.userContentController = self.userContentController;
    [configuration.preferences setValue:@YES forKey:@"developerExtrasEnabled"];

    self.webView = [[DraggableWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
    self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    [self.view addSubview:self.webView];

    __weak typeof(self) weakSelf = self;
    self.currentURLObserver = [KVOBlockObserver observe:self keyPath:@"webView.URL" block:^(id _Nonnull value) {
        [weakSelf queryToolbarColor];
        [weakSelf adjustV67Width];
        [weakSelf hideSidebar];
    }];

    self.baseURLObserver = [KVOBlockObserver observeUserDefaultsKey:ShouldUseFastmailBetaKey block:^(BOOL useBeta) {
        NSString *baseURLString = useBeta ? @"https://beta.fastmail.com" : @"https://www.fastmail.com";
        weakSelf.baseURL = [NSURL URLWithString:baseURLString];
        NSURL *mailURL = [weakSelf.baseURL URLByAppendingPathComponent:@"mail/compose" isDirectory:YES];
        [weakSelf.webView loadRequest:[NSURLRequest requestWithURL:mailURL]];
    }];
}

@end

// based on code found in this answer:
// https://stackoverflow.com/a/68434118

@implementation WKWebView (SyncBridge)
- (BOOL)evaluateJavaScript:(NSString *)script {
    //NSLog(@"Running evaluateJavaScript");
    BOOL __block waiting = YES;
    id __block retVal = nil;
    [self evaluateJavaScript: script completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        if (error == nil) {
            retVal = result;
        }
        waiting = FALSE;
    }];
    
    while (waiting) {
        [NSRunLoop.currentRunLoop acceptInputForMode:NSDefaultRunLoopMode beforeDate:NSDate.distantFuture];
    }
    return [retVal isEqual:@"true"];
}
@end


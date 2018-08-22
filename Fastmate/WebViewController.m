#import "WebViewController.h"
@import WebKit;

@interface WebViewController () <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) WKWebView *temporaryWebView;
@property (nonatomic, strong) WKUserContentController *userContentController;
@property (nonatomic, strong) NSURL *baseURL;

@end

@implementation WebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.baseURL = [NSURL URLWithString:@"https://www.fastmail.com"];
    [self configureUserContentController];

    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    configuration.applicationNameForUserAgent = @"Fastmate";
    configuration.userContentController = self.userContentController;

    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
    self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    [self.view addSubview:self.webView];

    [self.webView loadRequest:[NSURLRequest requestWithURL:self.baseURL]];
    [self addObserver:self forKeyPath:@"webView.URL" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"webView.URL"];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (webView == self.temporaryWebView) {
        // A temporary web view means we caught a link URL which we want to open externally
        [NSWorkspace.sharedWorkspace openURL:navigationAction.request.URL];
        decisionHandler(WKNavigationActionPolicyCancel);
        self.temporaryWebView = nil;
    } else if (navigationAction.request.URL.pathExtension.length > 0 && ![@[@"http", @"https"] containsObject:navigationAction.request.URL.pathExtension]) {
        // Probably a file URL, open externally
        [NSWorkspace.sharedWorkspace openURL:navigationAction.request.URL];
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    self.temporaryWebView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    self.temporaryWebView.navigationDelegate = self;
    return self.temporaryWebView;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == self && [keyPath isEqualToString:@"webView.URL"]) {
        [self webViewDidChangeURL:change[NSKeyValueChangeNewKey]];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)webViewDidChangeURL:(NSURL *)newURL {
    [self queryToolbarColor];
}

- (void)composeNewEmail {
    [self.webView evaluateJavaScript:@"fastmateCompose()" completionHandler:nil];
}

- (void)focusSearchField {
    [self.webView evaluateJavaScript:@"fastmateFocusSearch()" completionHandler:nil];
}

- (void)queryToolbarColor {
    [self.webView evaluateJavaScript:@"fastmateGetToolbarColor()" completionHandler:^(id response, NSError *error) {
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

- (void)setWindowBackgroundColor:(NSColor *)color {
    NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:color];
    [NSUserDefaults.standardUserDefaults setObject:colorData forKey:@"lastUsedWindowColor"];
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

- (void)configureUserContentController {
    self.userContentController = [WKUserContentController new];
    [self.userContentController addScriptMessageHandler:self name:@"Fastmate"];

    NSString *fastmateSource = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"Fastmate" withExtension:@"js"] encoding:NSUTF8StringEncoding error:nil];
    WKUserScript *fastmateScript = [[WKUserScript alloc] initWithSource:fastmateSource injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    [self.userContentController addUserScript:fastmateScript];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:[message.body dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];

    NSUserNotification *notification = [NSUserNotification new];
    notification.identifier = message.body;
    notification.title = dictionary[@"title"];
    notification.subtitle = [dictionary valueForKeyPath:@"options.body"];
    notification.soundName = NSUserNotificationDefaultSoundName;

    [NSUserNotificationCenter.defaultUserNotificationCenter deliverNotification:notification];
}

@end

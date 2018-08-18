#import "WebViewController.h"
@import WebKit;

@interface WebViewController () <WKNavigationDelegate, WKScriptMessageHandler>

@property (nonatomic, strong) WKWebView *webView;
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
    self.webView.enclosingScrollView.contentInsets = NSEdgeInsetsMake(40.0, 0.0, 0.0, 0.0);
    [self.view addSubview:self.webView];

    [self.webView loadRequest:[NSURLRequest requestWithURL:self.baseURL]];
}

- (void)composeNewEmail {
    [self.webView evaluateJavaScript:@"fastmateCompose()" completionHandler:nil];
}

- (void)focusSearchField {
    [self.webView evaluateJavaScript:@"fastmateFocusSearch()" completionHandler:nil];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)configureUserContentController {
    self.userContentController = [WKUserContentController new];
    [self.userContentController addScriptMessageHandler:self name:@"Fastmate"];

    NSString *notificationHooksSource = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"NotificationHooks" withExtension:@"js"] encoding:NSUTF8StringEncoding error:nil];
    WKUserScript *notificationHooksScript = [[WKUserScript alloc] initWithSource:notificationHooksSource injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    NSString *fastmateSource = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"Fastmate" withExtension:@"js"] encoding:NSUTF8StringEncoding error:nil];
    WKUserScript *fastmateScript = [[WKUserScript alloc] initWithSource:fastmateSource injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    [self.userContentController addUserScript:notificationHooksScript];
    [self.userContentController addUserScript:fastmateScript];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:[message.body dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    NSLog(@"%@", dictionary);

    NSUserNotification *notification = [NSUserNotification new];
    notification.identifier = message.body;
    notification.title = dictionary[@"title"];
    notification.subtitle = [dictionary valueForKeyPath:@"options.body"];
    notification.soundName = NSUserNotificationDefaultSoundName;

    if ([dictionary valueForKeyPath:@"options.icon"]) {
        NSURL *iconURL = [NSURL URLWithString:[dictionary valueForKeyPath:@"options.icon"] relativeToURL:self.baseURL];
        notification.contentImage = [[NSImage alloc] initWithContentsOfURL:iconURL];
    }

    [NSUserNotificationCenter.defaultUserNotificationCenter deliverNotification:notification];
}

@end

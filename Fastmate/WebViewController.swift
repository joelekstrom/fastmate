import Cocoa
import Combine
import WebKit

class WebViewController: NSViewController {

    let scriptController = ScriptController()
    @objc var webView: WKWebView?
    @Published var mailboxCounts = Dictionary<String, Int>()
    let externalURLSubject = PassthroughSubject<URL, Never>()
    let notificationClickSubject = PassthroughSubject<NotificationIdentifier, Never>()
    var notificationPublisher: AnyPublisher<FastmateNotification, Never> {
        scriptController.notificationPublisher
    }

    private let urlSubject = PassthroughSubject<URL, Never>()
    private let scriptSubject = PassthroughSubject<String, Never>()
    private var temporaryWebView: WKWebView?
    private var alertSubscription: AnyCancellable?
    private var subscriptions = Set<AnyCancellable>()

    private let baseURLPublisher = Settings.shared.$shouldUseFastmailBeta.publisher
        .map { URL(string: $0 ? "https://beta.fastmail.com" : "https://www.fastmail.com")! }

    override func viewDidLoad() {
        super.viewDidLoad()

        let configuration = WKWebViewConfiguration()
        configuration.applicationNameForUserAgent = "Fastmate"
        configuration.userContentController = scriptController.userContentController

        let webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.uiDelegate = self

        view.addSubview(webView)
        self.webView = webView

        setupSubscriptions()
    }

    private func setupSubscriptions() {
        guard let webView = webView else { return }

        urlSubject
            .sink { webView.load(URLRequest(url: $0)) }
            .store(in: &subscriptions)

        baseURLPublisher
            .subscribe(urlSubject)
            .store(in: &subscriptions)

        scriptSubject
            .sink { webView.evaluateJavaScript($0, completionHandler: nil) }
            .store(in: &subscriptions)

        let backgroundColorPublisherFactory = {
            webView.scriptResultPublisher(for: "Fastmate.getToolbarColor()")
                .compactMap { $0 as? String }
                .compactMap(Self.convertToolbarColor(from:))
                .tryMap { try Optional(NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)) }
                .replaceError(with: nil)
                .compactMap { $0 }
        }

        scriptController.documentDidChange
            .flatMap { _ in backgroundColorPublisherFactory() }
            .removeDuplicates()
            .assign(to: \.windowBackgroundColor, on: Settings.shared)
            .store(in: &subscriptions)

        scriptController.documentDidChange
            .flatMap { _ in webView.scriptResultPublisher(for: "Fastmate.getMailboxUnreadCounts()")
                .compactMap { $0 as? Dictionary<String, Int> }
                .replaceError(with: [:])
            }
            .assign(to: \.mailboxCounts, on: self)
            .store(in: &subscriptions)

        scriptController.$hoveredURL
            .map { $0 == nil }
            .assign(to: \.isHidden, on: linkPreviewTextField)
            .store(in: &subscriptions)

        scriptController.$hoveredURL
            .compactMap { $0?.absoluteString }
            .assign(to: \.stringValue, on: linkPreviewTextField)
            .store(in: &subscriptions)

        let printController = PrintController(webView: webView)
        scriptController.print
            .sink { printController.print() }
            .store(in: &subscriptions)

        NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification)
            .sink { _ in webView.reload() }
            .store(in: &subscriptions)

        let fastmateURLPublisher = externalURLSubject
            .filter { $0.scheme == "fastmate" }
            .combineLatest(baseURLPublisher)
            .compactMap { (url, baseURL) -> URL? in
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.scheme = "https"
                components?.host = baseURL.host
                return components?.url
            }

        let mailtoURLPublisher = externalURLSubject
            .filter { $0.scheme == "mailto" }
            .combineLatest(baseURLPublisher)
            .compactMap { (mailToURL, baseURL) -> URL? in
                var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
                components?.path = "/action/compose/"
                let mailtoString = mailToURL.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                components?.percentEncodedQueryItems = [URLQueryItem(name: "mailto", value: mailtoString)]
                return components?.url
            }

        fastmateURLPublisher.merge(with: mailtoURLPublisher)
            .subscribe(urlSubject)
            .store(in: &subscriptions)

        notificationClickSubject
            .map { "Fastmate.handleNotificationClick(\"\($0)\")" }
            .subscribe(scriptSubject)
            .store(in: &subscriptions)
    }

    @IBAction func copyLinkToCurrentItem(_ sender: AnyObject) {
        if let currentURL = webView?.url {
            copyURLToPasteboard(currentURL)
        }
    }

    @IBAction func copyFastmateLinkToCurrentItem(_ sender: AnyObject) {
        guard let currentURL = webView?.url else { return }
        var components = URLComponents(url: currentURL, resolvingAgainstBaseURL: true)
        components?.scheme = "fastmate"
        components?.host = "app"
        if let fastmateURL = components?.url {
            copyURLToPasteboard(fastmateURL)
        }
    }

    @IBAction func printMail(_ sender: AnyObject) {
        scriptController.print.send()
    }

    @IBAction func focusSearchField(_ sender: AnyObject) {
        scriptSubject.send("Fastmate.focusSearch()")
    }

    @IBAction func composeNewEmail(_ sender: AnyObject) {
        scriptSubject.send("Fastmate.compose()")
    }

    private func copyURLToPasteboard(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL, url.absoluteString as NSString])
        if let title = webView?.title?.components(separatedBy: " – ").last {
            let bearNotesTitleType = NSPasteboard.PasteboardType(rawValue: "net.shinyfrog.bear.url-name")
            pasteboard.setString(title, forType: bearNotesTitleType)
            if url.scheme == "https" {
                let chromiumTitleType = NSPasteboard.PasteboardType(rawValue: "public.url-name")
                pasteboard.setString(title, forType: chromiumTitleType)
            }
        }
    }

    private lazy var linkPreviewTextField: NSTextField = {
        let textField = NSTextField(labelWithString: "")
        textField.wantsLayer = true
        textField.drawsBackground = false
        textField.layer?.backgroundColor = NSColor.darkGray.withAlphaComponent(0.8).cgColor
        textField.layer?.borderColor = NSColor.white.withAlphaComponent(0.65).cgColor
        textField.layer?.borderWidth = 1
        textField.layer?.cornerRadius = 3.5
        textField.textColor = NSColor.white
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.cell?.lineBreakMode = NSLineBreakMode.byTruncatingMiddle
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.addSubview(textField)
        textField.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.75).isActive = true
        view.rightAnchor.constraint(equalTo: textField.rightAnchor, constant: 4).isActive = true
        view.bottomAnchor.constraint(equalTo: textField.bottomAnchor, constant: 2).isActive = true
        return textField
    }()

    private static func convertToolbarColor(from string: String) -> NSColor? {
        let components = string.replacingOccurrences(of: "rgb(", with: "")
                               .replacingOccurrences(of: ")", with: "")
                               .components(separatedBy: ",")
                               .map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
        guard
            let red = Float(components[0]),
            let green = Float(components[1]),
            let blue = Float(components[2])
        else {
            return nil
        }
        return NSColor(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0 , blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
}

extension WebViewController: WKNavigationDelegate, WKUIDelegate {

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        temporaryWebView = WKWebView(frame: .zero, configuration: configuration)
        temporaryWebView!.navigationDelegate = self
        return temporaryWebView
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let isFastmailLink = navigationAction.request.url?.host?.hasSuffix(".fastmail.com") ?? false
        if webView == temporaryWebView {
            // A temporary web view means we caught a link URL which Fastmail wants to open externally (like a new tab).
            // However, if  it's a user-added link to an e-mail, prefer to open it within Fastmate itself
            let isEmailLink = isFastmailLink && navigationAction.request.url?.path.hasPrefix("/mail/") ?? false
            if isEmailLink {
                urlSubject.send(navigationAction.request.url!)
            } else {
                NSWorkspace.shared.open(navigationAction.request.url!)
            }
            decisionHandler(.cancel)
            temporaryWebView = nil
        } else if navigationAction.request.url?.host?.hasSuffix(".fastmailusercontent.com") ?? false {
            let components = URLComponents(url: navigationAction.request.url!, resolvingAgainstBaseURL: false)
            let shouldDownload = (components?.queryItems?.firstIndex(where: { $0.name == "download" && $0.value == "1" }) ?? NSNotFound) != NSNotFound
            if shouldDownload {
                NSWorkspace.shared.open(navigationAction.request.url!)
            }
            decisionHandler(shouldDownload == false ? .allow : .cancel)
        } else if isFastmailLink {
            decisionHandler(.allow)
        } else {
            // Link isn't within fastmail.com, open externally
            NSWorkspace.shared.open(navigationAction.request.url!)
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canCreateDirectories = false
        panel.beginSheetModal(for: webView.window!) {
            completionHandler($0 == .OK ? panel.urls : nil)
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        alertSubscription = Just(Alert.Configuration(messageText: message, buttonTitles: ["OK", "Cancel"]))
            .displayAlert(window: webView.window!)
            .sink { completionHandler( $0.modalResponse == .alertFirstButtonReturn ) }
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        alertSubscription = Just(Alert.Configuration(messageText: message, buttonTitles: ["OK"]))
            .displayAlert(window: webView.window!)
            .sink { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let textField = NSTextField(frame: .init(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = defaultText ?? ""

        alertSubscription = Just(Alert.Configuration(messageText: prompt, buttonTitles: ["OK", "Cancel"], accessoryView: textField))
            .displayAlert(window: webView.window!)
            .sink { completionHandler($0.modalResponse == .alertFirstButtonReturn ? textField.stringValue : defaultText) }
    }

}

extension WKWebView {
    func scriptResultPublisher(for script: String) -> AnyPublisher<Any, Error> {
        Future { promise in
            self.evaluateJavaScript(script) { (result, error) in
                if let error = error {
                    promise(.failure(error))
                } else {
                    promise(.success(result!))
                }
            }
        }.eraseToAnyPublisher()
    }
}

class ScriptController: NSObject, WKScriptMessageHandler {

    let notificationPublisher: AnyPublisher<FastmateNotification, Never>
    let userContentController = WKUserContentController()
    let documentDidChange = PassthroughSubject<Void, Never>()
    let print = PassthroughSubject<Void, Never>()
    @Published private(set) var hoveredURL: URL?

    private let notificationSubject = PassthroughSubject<WKScriptMessage, Never>()

    private static let userScriptsDirectoryPath = (NSHomeDirectory() as NSString).appendingPathComponent("userscripts")

    override init() {
        notificationPublisher = notificationSubject
            .compactMap { $0.body as? String }
            .compactMap { $0.data(using: .utf8) }
            .flatMap {
                Just($0)
                    .tryCompactMap { try JSONSerialization.jsonObject(with: $0, options: []) as? Dictionary<String, Any> }
                    .replaceError(with: nil)
                    .compactMap { $0 }
            }
            .compactMap { data -> FastmateNotification? in
                guard let notificationID = data["notificationID"] as? Int, let title = data["title"] as? String else { return nil }
                let options = data["options"] as? Dictionary<String, Any>
                let body = options?["body"] as? String ?? ""
                return FastmateNotification(identifier: String(notificationID), title: title, body: body)
            }
            .eraseToAnyPublisher()

        super.init()
        userContentController.add(self, name: "Fastmate")
        userContentController.add(self, name: "LinkHover")
        let fastmateSource = try! String(contentsOf: Bundle.main.url(forResource: "Fastmate", withExtension: "js")!, encoding: .utf8)
        let fastmateScript = WKUserScript(source: fastmateSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(fastmateScript)
        loadUserScripts()
    }

    private func loadUserScripts() {
        guard let enumerator = FileManager.default.enumerator(atPath: Self.userScriptsDirectoryPath) else { return }

        for obj in enumerator {
            let filename = obj as! NSString
            guard filename.pathExtension == "js" else { continue }
            let filePath = Self.userScriptsDirectoryPath.appending(filename as String)
            if let scriptContent = try? String(contentsOfFile: filePath) {
                #warning("testa")
                let script = WKUserScript(source: scriptContent, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
                userContentController.addUserScript(script)
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "LinkHover" {
            let urlString = message.body as? String
            hoveredURL = URL(string: urlString ?? "")
        } else if message.body as? String == "documentDidChange" {
            documentDidChange.send()
        } else if message.body as? String == "print" {
            print.send()
        } else {
            notificationSubject.send(message)
        }
    }

    static func createUserScriptsFolderIfNeeded() {
        var folderExists = ObjCBool(false)
        let path = ScriptController.userScriptsDirectoryPath
        FileManager.default.fileExists(atPath: path, isDirectory: &folderExists)
        if folderExists.boolValue == false {
            createUserScriptsFolder(path: path)
        }
    }

    private static func createUserScriptsFolder(path: String) {
        let readmePath = (path as NSString).appendingPathComponent("README.txt")
        let readmeData = """
        Fastmate user scripts\n\n
        Put JavaScript files in this folder (.js), and Fastmate will load them at document end after loading the Fastmail website.\n
        """.data(using: .utf8)
        do {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
            FileManager.default.createFile(atPath: readmePath, contents: readmeData, attributes: nil)
        }
    }

}

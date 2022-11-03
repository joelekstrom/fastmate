import Foundation
import WebKit

@MainActor
class WebViewDelegate: NSObject {
    /// Invoked when a request from a temporary hidden web view should be opened in the main web view
    @objc var requestHandler: ((URLRequest) -> Void)?

    /// Set when Fastmail attempts to open a new window/tab. Used to capture navigation events that could
    /// be handled within Fastmate
    private var temporaryWebView: WKWebView?
}

extension WebViewDelegate: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        temporaryWebView = WKWebView(frame: .zero, configuration: configuration)
        temporaryWebView?.navigationDelegate = self
        return temporaryWebView
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo) async -> [URL]? {
        guard let window = webView.window else { return nil }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canCreateDirectories = false
        let result = await panel.beginSheetModal(for: window)
        return result == .OK ? panel.urls : nil
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async -> Bool {
        guard let window = webView.window else { return false }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = message
        _ = alert.addButton(withTitle: "OK")
        _ = alert.addButton(withTitle: "Cancel")
        let returnCode = await alert.beginSheetModal(for: window)
        return returnCode == .alertFirstButtonReturn
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async {
        guard let window = webView.window else { return }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = message
        _ = alert.addButton(withTitle: "OK")
        _ = await alert.beginSheetModal(for: window)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo) async -> String? {
        guard let window = webView.window else { return nil }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = prompt
        _ = alert.addButton(withTitle: "OK")
        _ = alert.addButton(withTitle: "Cancel")
        let textField = NSTextField(frame: .init(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = defaultText ?? ""
        alert.accessoryView = textField
        let returnCode = await alert.beginSheetModal(for: window)
        return returnCode == .alertFirstButtonReturn ? textField.stringValue : defaultText
    }
}

extension WebViewDelegate: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard webView == temporaryWebView else {
            preconditionFailure("This navigation delegate is currently only used to capture temp web view events")
        }

        defer { temporaryWebView = nil }
        guard let url = navigationAction.request.url else { return .cancel }

        // A temporary web view means we caught a link URL which Fastmail wants to open externally (like a new tab).
        // However, if  it's a user-added link to an e-mail, prefer to open it within Fastmate itself
        let isFastmailLink = url.host?.hasSuffix(".fastmail.com") ?? false
        let isEmailLink = isFastmailLink && url.path.hasPrefix("/mail/")
        if isEmailLink {
            requestHandler?(navigationAction.request)
        } else {
            NSWorkspace.shared.open(url)
        }
        return .cancel
    }
}

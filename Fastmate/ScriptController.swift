import Foundation
import Combine
import WebKit

class ScriptController: NSObject, WKScriptMessageHandler {

    let userContentController = WKUserContentController()

    let notificationPublisher: AnyPublisher<FastmateNotification, Never>
    let documentDidChangePublisher = PassthroughSubject<Void, Never>()
    let printPublisher = PassthroughSubject<Void, Never>()
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
            let filePath = Self.userScriptsDirectoryPath.appending("/\(filename)")
            if let scriptContent = try? String(contentsOfFile: filePath) {
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
            documentDidChangePublisher.send()
        } else if message.body as? String == "print" {
            printPublisher.send()
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

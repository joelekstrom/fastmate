import Foundation
import Combine

class FastmateAppDelegate: NSObject, NSApplicationDelegate {

    let didFinishLaunching = PassthroughSubject<Void, Never>()
    let checkForNewVersionAction = PassthroughSubject<Void, Never>()

    static var shared: FastmateAppDelegate {
//        NSApplication.shared.delegate as! FastmateAppDelegate
        (NSApplication.shared.delegate as! AppDelegate).forwardingSwiftDelegate
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        didFinishLaunching.send()
        VersionChecker.setup()
    }

    @IBAction func checkForUpdates(sender: AnyObject) {
        checkForNewVersionAction.send()
    }

}

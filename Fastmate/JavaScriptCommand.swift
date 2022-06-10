//
//  ScriptCommand.swift
//  Fastmate
//
//  Created by Maarten den Braber on 05/06/2022.
//

import Foundation

class JavaScriptCommand : NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        if let directParameter = directParameter as? String {
            let appDelegate = NSApplication.shared.delegate as? AppDelegate
            appDelegate?.mainWebViewController?.webView?.evaluateJavaScript(directParameter)
        } else {
            self.scriptErrorNumber = -50;
            self.scriptErrorString = "Provide a JavaScript string to evaluate"
        }
        return nil
    }
}

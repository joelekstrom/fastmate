//
//  ScriptCommand.swift
//  Fastmate
//
//  Created by Maarten den Braber on 05/06/2022.
//

import Foundation

class JavaScriptCommand : NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        var javascriptString = ""
        
        if ((self.directParameter) != nil) {
            javascriptString = self.directParameter as! String
        } else {
            self.scriptErrorNumber = -50;
            self.scriptErrorString = "Provide a JavaScript string to evaluate"
        }
        
        let appDelegate = NSApplication.shared.delegate as? AppDelegate
        let mainWebViewController = appDelegate?.mainWebViewController as? WebViewController
        mainWebViewController?.webView?.evaluateJavaScript(javascriptString)
    
        return nil

    }
}

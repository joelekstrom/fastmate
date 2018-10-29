var Fastmate = {

    simulateKeyPress: function(key) {
        var e = new Event("keydown");
        e.key = key;
        e.keyCode = e.key.charCodeAt(0);
        e.which = e.keyCode;
        e.altKey = false;
        e.ctrlKey = false;
        e.shiftKey = false;
        e.metaKey = false;
        e.bubbles = true;
        document.dispatchEvent(e);
    },

    compose: function() {
        Fastmate.simulateKeyPress("c");
    },

    focusSearch: function() {
        Fastmate.simulateKeyPress("/");
    },

    getToolbarColor: function() {
        var toolbar = document.getElementsByClassName("app-toolbar")[0];
        var style = window.getComputedStyle(toolbar);
        var color = style.getPropertyValue('background-color');
        return color;
    }
};

/**
 Web Notification observering

 Since Web Notifications are not natively supported by WKWebView, we hook into the
 notification function and post a webkit message handler instead.

 We also set the notification permission to 'granted' since WKWebView doesn't
 have a built in way to ask for permission.
*/
var originalNotification = Notification;
Notification = function(title, options) {
    window.webkit.messageHandlers.Fastmate.postMessage('{"title": "' + title + '", "options": ' + JSON.stringify(options) + '}');
    return originalNotification(title, options);
}

Object.defineProperty(Notification, 'permission', { value: 'granted', writable: false });

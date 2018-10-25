var Fastmate = {
    compose: function() {
        FastMail.mail.set("screen", "compose");
    },

    focusSearch: function() {
        var toolbar = document.getElementsByClassName("app-toolbar")[0];
        var searchField = toolbar.querySelectorAll("input.v-Text-input")[0];
        if (!searchField) {
            searchField = document.getElementById("v9-input");
        }
        searchField.select();
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

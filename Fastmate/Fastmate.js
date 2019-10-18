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
        var toolbar = document.getElementsByClassName("v-PageHeader")[0];
        var style = window.getComputedStyle(toolbar);
        var color = style.getPropertyValue('background-color');
        return color;
    },

    getMailboxUnreadCounts: function() {
        var mailboxes = document.getElementsByClassName("v-MailboxSource");
        var result = {};
        for (var i = 0; i < mailboxes.length; ++i) {
            var mailbox = mailboxes[i];
            var labelElement = mailbox.getElementsByClassName("app-source-name")[0];
            var badgeElement = mailbox.getElementsByClassName("v-MailboxSource-badge")[0];
            var name = labelElement.innerHTML;
            var count = 0;
            if (badgeElement) {
                var c = parseInt(badgeElement.innerHTML);
                count = isNaN(c) ? 0 : c;
            }
            result[name] = count;
        }
        return result;
    },

    notificationClickHandlers: {}, // notificationID -> function

    handleNotificationClick: function(id) {
        var handler = Fastmate.notificationClickHandlers[id]();
        if (handler) handler();
    },
    
    adjustV67Width: function() {
        document.getElementById("v67").style.maxWidth = "100%";
    },
};

/**
 Web Notification observering

 Since Web Notifications are not natively supported by WKWebView, we hook into the
 notification function and post a webkit message handler instead.

 We also set the notification permission to 'granted' since WKWebView doesn't
 have a built in way to ask for permission.
*/
var originalNotification = Notification;
var notificationID = 0;
Notification = function(title, options) {
    ++notificationID;
    var n = new originalNotification(title, options);
    Object.defineProperty(n, "onclick", { set: function(value) { Fastmate.notificationClickHandlers[notificationID.toString()] = value; }});
    window.webkit.messageHandlers.Fastmate.postMessage('{"title": "' + title + '", "options": ' + JSON.stringify(options) + ', "notificationID": ' + notificationID + '}');
    return n;
}

Object.defineProperty(Notification, 'permission', { value: 'granted', writable: false });


/**
 Observe changes to the DOM
 */
var DOMObserver = new MutationObserver(function(mutation) { window.webkit.messageHandlers.Fastmate.postMessage('documentDidChange'); });
var config = {
    attributes: true,
    characterData: true,
    childList: true,
    subtree: true,
};
DOMObserver.observe(document, config);

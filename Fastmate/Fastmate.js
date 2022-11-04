var Fastmate = {

    simulateKeyPress: function(key) {
        document.dispatchEvent(new KeyboardEvent('keydown', {'key': key}));
    },

    compose: function() {
        Fastmate.simulateKeyPress('c')
        return true
    },

    focusSearch: function() {
        Fastmate.simulateKeyPress('/')
        return true
    },

    nextMessage: function() {
        Fastmate.simulateKeyPress('k')
        return true
    },
        
    previousMessage: function() {
        Fastmate.simulateKeyPress('j')
        return true
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
            if (mailbox.classList.contains("v-MailboxSource--drafts")) {
                continue; // Exclude drafts folder in count
            }
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

    documentDidChange: function() {
        window.webkit.messageHandlers.DocumentDidChange.postMessage(null);
        Fastmate.addLinkMouseListeners()
    },

    // Adds mouse enter/exit listeners to all <a> elements inside the e-mail message body
    addLinkMouseListeners: function() {
        var messageBody = document.getElementsByClassName("v-Message-body")[0];
        if (messageBody == null) {
            return;
        }

        var linkNodes = messageBody.getElementsByTagName("a");
        Array.prototype.forEach.call(linkNodes, function(link) {
            var href = link.href;
            link.addEventListener('mouseenter', e => {
                window.webkit.messageHandlers.LinkHover.postMessage(href);
            });
            link.addEventListener('mouseleave', e => {
                window.webkit.messageHandlers.LinkHover.postMessage(null);
            });
        });
    },
};

// Catch the print function so we can forward it to PrintManager
print = function() { window.webkit.messageHandlers.Print.postMessage(); };

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
    var message = {
        "title": title,
        "options": options,
        "notificationID": notificationID
    };
    window.webkit.messageHandlers.Notification.postMessage(JSON.stringify(message));
    return n;
}

Object.defineProperty(Notification, 'permission', { value: 'granted', writable: false });


/**
 Observe changes to the DOM
 */
var DOMObserver = new MutationObserver(function(mutations) { Fastmate.documentDidChange(); });
var config = {
    attributes: false,
    characterData: true,
    childList: true,
    subtree: true,
};
DOMObserver.observe(document.body, config);

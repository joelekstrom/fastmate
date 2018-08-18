var originalNotification = Notification;
Notification = function(title, options) {
    window.webkit.messageHandlers.Fastmate.postMessage('{"title": "' + title + '", "options": ' + JSON.stringify(options) + '}');
    return originalNotification(title, options);
}

Object.defineProperty(Notification, 'permission', { value: 'granted', writable: false });

# Fastmate
<img src="Fastmate/Assets.xcassets/AppIcon.appiconset/fastmate-256.png" alt="Fastmate logo" height="80" width="80" />

A native [Fastmail](https://www.fastmail.com/)-wrapper for Mac.

## Features
- Desktop notifications for new mail
- Handles e-mail (mailto:) links
  - Can be set as your default e-mail software
- Dock badge for unread mail
- Status bar notifier (has to be enabled in settings)
- OSX shortcuts (<kbd>⌘N</kbd> for new draft, <kbd>⌘F</kbd> to search mail)
- User scripts
- Uses the system web stack

![screenshot](screenshot.png)

## Installation

Pre-built binaries can be found on the [release page](https://github.com/joelekstrom/fastmate/releases). To build it yourself you need to have Xcode and either disable code signing or change the bundle identifier to something else prior to compiling.

Fastmate requires macOS 10.15 (Catalina) or newer since version 1.8.1. If you're running an older macOS, please download [v1.8.0](https://github.com/joelekstrom/fastmate/releases/tag/v1.8.0).

A Homebrew cask is available at [rajiv/homebrew-fastmate](https://github.com/rajiv/homebrew-fastmate). Fastmate can be installed using:

```shell-script
brew install rajiv/fastmate/fastmate
```

## Enabling push notifications
For Fastmate to receive push notifications for new e-mail, it has to be enabled within the _Fastmail_ settings from within Fastmate. It's disabled by default. Click the Fastmail logo in the top left of the window -> Settings -> Notifications -> check "Show a notification" for new messages.

## Enabling Status Bar and Dock Notifications
Upon installation, Fastmate should prompt you to allow notifications.  If this was missed, or you find your status bar and dock notifications are not working, please check the Fastmate-specific notification settings within MacOS by going to System Preferences->Notifications & Focus and ensure that "Allow Notifications" is enabled for Fastmate.  For more information on these features, please see https://github.com/joelekstrom/fastmate/discussions/60

## Setting as default e-mail software
If you want Fastmate to be the handler of `mailto://`-links, follow the guide at https://support.apple.com/en-us/HT201607 and choose Fastmate as "Default e-mail reader".

## Adding user scripts
Click Fastmate -> Preferences... -> User Scripts...

this will open a Finder-window with a folder where you can put `.js` files with your custom scripts.

# AppleScript support

Fastmate understands basic AppleScript commands: `get title` (current title), `get url` (current URL) and `javascript <string>` (execute arbitrary JavaScript in the webView):

 ```applescript
 tell application id "io.ekstrom.Fastmate"
     set theURL to get url
     set theTitle to get title
     javascript "alert('URL: " & theURL & "/ Title: " & theTitle & "')"
 end tell
 ```
 
You can use the `javascript` call to e.g. create your own `click` events (or anything you'd like) inside the Fastmail UI.

## Troubleshooting

### Fastmate crashes on launch
This happens for some people on Mojave. It might be because of "app translocation". Moving the app into /Applications/ should solve the problem.

## Privacy
Your Fastmail login and e-mail are handled entirely by `WKWebView`, meaning that it is pretty much the same as running Fastmail in Safari. Fastmate does have access to the DOM and could potentially read your mail (it doesn't, but the privacy inclined might want to verify the source).

Here's what Fastmate does read:
- The title of the web page (what's shown in the tab when running Fastmail in your web browser) to show the unread mail counter.
- The unread count of each folder (depending on your settings)
- Web Notifications - Fastmate has a hook that simply forwards any web notifications to the OSX notification center. It does not read the contents of your notifications.
- The background color of the Fastmail toolbar, to be able to match your chosen Fastmail-theme.

Fastmate by default sends one network request outside of what Fastmail sends internally - it pings https://github.com/joelekstrom/fastmate/releases/latest
once a week to inform you if a new version is available. You can opt out of this in the settings.

## Disclaimer
Fastmate is not affilated with Fastmail in any way. This is a project I work on in my free time,
and both the binaries and source code are available for free and for anyone to use.

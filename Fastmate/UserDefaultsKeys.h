#ifndef UserDefaultsKeys_h
#define UserDefaultsKeys_h
#import "Fastmate-Swift.h"

#define ArrowNavigatesMessageListKey        NSStringFromSelector(@selector(arrowNavigatesMessageList))
#define DownloadsPathKey                    NSStringFromSelector(@selector(downloadsPath))
#define DownloadBehaviorKey                 NSStringFromSelector(@selector(downloadBehavior))
#define ShouldShowStatusBarIconKey          NSStringFromSelector(@selector(shouldShowStatusBarIcon))
#define ShouldShowUnreadMailIndicatorKey    NSStringFromSelector(@selector(shouldShowUnreadMailIndicator))
#define ShouldShowUnreadMailInDockKey       NSStringFromSelector(@selector(shouldShowUnreadMailInDock))
#define ShouldShowUnreadMailCountInDockKey  NSStringFromSelector(@selector(shouldShowUnreadMailCountInDock))
#define ShouldShowUnreadMailInStatusBarKey  NSStringFromSelector(@selector(shouldShowUnreadMailInStatusBar))
#define ShouldOpenSafeDownloadsKey          NSStringFromSelector(@selector(shouldOpenSafeDownloads))
#define ShouldUseFastmailBetaKey            NSStringFromSelector(@selector(shouldUseFastmailBeta))
#define WatchedFolderTypeKey                NSStringFromSelector(@selector(watchedFolderType))
#define WatchedFoldersKey                   NSStringFromSelector(@selector(watchedFolders))
#define WindowBackgroundColorKey            NSStringFromSelector(@selector(lastUsedWindowColor))
#define ShouldDownloadUsingExternalBrowserKey  NSStringFromSelector(@selector(shouldDownloadInExternalBrowser))

#endif /* UserDefaultsKeys_h */

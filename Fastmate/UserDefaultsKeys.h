#ifndef UserDefaultsKeys_h
#define UserDefaultsKeys_h

typedef NS_ENUM(NSUInteger, WatchedFolderType) {
    WatchedFolderTypeDefault,
    WatchedFolderTypeAll,
    WatchedFolderTypeSpecific
};

#define ArrowNavigatesMessageListKey        @"arrowNavigatesMessageList"
#define AutomaticUpdateChecksKey            @"automaticUpdateChecks"
#define ShouldShowStatusBarIconKey          @"shouldShowStatusBarIcon"
#define ShouldShowUnreadMailIndicatorKey    @"shouldShowUnreadMailIndicator"
#define ShouldShowUnreadMailInDockKey       @"shouldShowUnreadMailInDock"
#define ShouldShowUnreadMailCountInDockKey  @"shouldShowUnreadMailCountInDock"
#define ShouldShowUnreadMailInStatusBarKey  @"shouldShowUnreadMailInStatusBar"
#define ShouldUseFastmailBetaKey            @"shouldUseFastmailBeta"
#define ShouldUseTransparentTitleBarKey     @"shouldUseTransparentTitleBar"
#define WatchedFolderTypeKey                @"watchedFolderType"
#define WatchedFoldersKey                   @"watchedFolders"
#define WindowBackgroundColorKey            @"lastUsedWindowColor"
#define MainWindowFrameKey                  @"mainWindowFrame"

#endif /* UserDefaultsKeys_h */

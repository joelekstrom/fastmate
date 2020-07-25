#ifndef UserDefaultsKeys_h
#define UserDefaultsKeys_h

typedef NS_ENUM(NSUInteger, WatchedFolderType) {
    WatchedFolderTypeDefault,
    WatchedFolderTypeAll,
    WatchedFolderTypeSpecific
};

#define ShouldShowStatusBarIconKey          @"shouldShowStatusBarIcon"
#define ShouldShowUnreadMailIndicatorKey    @"shouldShowUnreadMailIndicator"
#define ShouldShowUnreadMailInDockKey       @"shouldShowUnreadMailInDock"
#define ShouldShowUnreadMailCountInDockKey  @"shouldShowUnreadMailCountInDock"
#define ShouldShowUnreadMailInStatusBarKey  @"shouldShowUnreadMailInStatusBar"
#define ShouldUseFastmailBetaKey            @"shouldUseFastmailBeta"
#define WatchedFolderTypeKey                @"watchedFolderType"
#define WatchedFoldersKey                   @"watchedFolders"
#define WindowBackgroundColorKey            @"windowBackgroundColor"

//#define AutomaticUpdateChecksKey            @"automaticUpdateChecks"
//#define ShouldUseTransparentTitleBarKey     @"shouldUseTransparentTitleBar"
//#define MainWindowFrameKey                  @"mainWindowFrame"

#endif /* UserDefaultsKeys_h */

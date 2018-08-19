#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, FastmateIconVisibility) {
    FastmateIconVisibilityDock = 0,
    FastmateIconVisibilityStatusBar = 1,
    FastmateIconVisibilityBoth = 2
};

@interface SettingsViewController : NSViewController

@end

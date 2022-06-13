#import "SettingsViewController.h"
#import "UserDefaultsKeys.h"

@interface SettingsViewController () <NSPathControlDelegate>

@property (nonatomic, weak) IBOutlet NSButton *defaultWatchedFoldersButton;
@property (nonatomic, weak) IBOutlet NSButton *allWatchedFoldersButton;
@property (nonatomic, weak) IBOutlet NSButton *specificWatchedFoldersButton;
@property (nonatomic, weak) IBOutlet NSPathControl *downloadsPathControl;
@property (nonatomic, weak) IBOutlet NSButton *keepDownloadBehaviorButton;
@property (nonatomic, weak) IBOutlet NSButton *overwriteDownloadBehaviorButton;
@property (nonatomic, weak) IBOutlet NSButton *askDownloadBehaviorButton;


@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    WatchedFolderType watchedFolderType = [NSUserDefaults.standardUserDefaults integerForKey:WatchedFolderTypeKey];
    NSArray *watchedButtons = @[self.defaultWatchedFoldersButton, self.allWatchedFoldersButton, self.specificWatchedFoldersButton];
    [watchedButtons[watchedFolderType] setState:NSControlStateValueOn];

    [_downloadsPathControl setURL: [NSUserDefaults.standardUserDefaults URLForKey:DownloadsPathKey]];

    DownloadBehaviorType downloadBehaviorType = [NSUserDefaults.standardUserDefaults integerForKey:DownloadBehaviorKey];
    NSArray *downloadBehaviorButtons = @[self.keepDownloadBehaviorButton, self.overwriteDownloadBehaviorButton, self.askDownloadBehaviorButton];
    [downloadBehaviorButtons[downloadBehaviorType] setState:NSControlStateValueOn];
}

- (IBAction)watchedFolderButtonSelected:(NSButton *)sender {
    [NSUserDefaults.standardUserDefaults setInteger:sender.tag forKey:WatchedFolderTypeKey];
}

- (IBAction)openUserScriptsFolder:(id)sender {
    [NSWorkspace.sharedWorkspace openFile:[NSHomeDirectory() stringByAppendingPathComponent:@"userscripts"]];
}

- (IBAction)downloadBehaviorButtonSelected:(NSButton *)sender {
    [NSUserDefaults.standardUserDefaults setInteger:sender.tag forKey:DownloadBehaviorKey];
}

-(IBAction)downloadsPathClicked:(id)sender {
    [NSUserDefaults.standardUserDefaults setValue:[[_downloadsPathControl URL] path] forKey:DownloadsPathKey];
}



- (void)pathControl:(NSPathControl *)pathControl willPopUpMenu:(NSMenu *)menu {
    // We don't want to show the useless "parent folders" menu items, as they are very confusing.
    while ([[menu itemArray] count] >= 4) {
        [menu removeItemAtIndex:3];
    }
}

@end

// This simply transforms the tag of a button to a bool, to check if the
// selected radio button is "Specific folders" in cocoa bindings.
@interface WatchedFolderTypeIsSpecificFolders: NSValueTransformer {} @end

@implementation WatchedFolderTypeIsSpecificFolders

+ (Class)transformedValueClass {
    return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(NSNumber *)value {
    return (value.integerValue == 2) ? @YES : @NO;
}

@end

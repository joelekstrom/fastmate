#import "SettingsViewController.h"
#import "UserDefaultsKeys.h"

@interface SettingsViewController ()

@property (nonatomic, weak) IBOutlet NSButton *defaultWatchedFoldersButton;
@property (nonatomic, weak) IBOutlet NSButton *allWatchedFoldersButton;
@property (nonatomic, weak) IBOutlet NSButton *specificWatchedFoldersButton;

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    WatchedFolderType type = [NSUserDefaults.standardUserDefaults integerForKey:WatchedFolderTypeKey];
    NSArray *buttons = @[self.defaultWatchedFoldersButton, self.allWatchedFoldersButton, self.specificWatchedFoldersButton];
    [buttons[type] setState:NSControlStateValueOn];
}

- (IBAction)watchedFolderButtonSelected:(NSButton *)sender {
    [NSUserDefaults.standardUserDefaults setInteger:sender.tag forKey:WatchedFolderTypeKey];
}

- (IBAction)openUserScriptsFolder:(id)sender {
    [NSWorkspace.sharedWorkspace openFile:[NSHomeDirectory() stringByAppendingPathComponent:@"userscripts"]];
}

- (IBAction)openUserStylesFolder:(id)sender {
    [NSWorkspace.sharedWorkspace openFile:[NSHomeDirectory() stringByAppendingPathComponent:@"userstyles"]];
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

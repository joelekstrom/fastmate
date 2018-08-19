#import "SettingsViewController.h"

@interface SettingsViewController ()

@property (nonatomic, weak) IBOutlet NSButton *showStatusBarIconRadioButton;
@property (nonatomic, weak) IBOutlet NSButton *showDockIconRadioButton;
@property (nonatomic, weak) IBOutlet NSButton *showBothRadioButton;

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    FastmateIconVisibility visibility = [[NSUserDefaults standardUserDefaults] integerForKey:@"iconVisibility"];
    switch (visibility) {
        case FastmateIconVisibilityDock: self.showDockIconRadioButton.state = NSControlStateValueOn; break;
        case FastmateIconVisibilityStatusBar: self.showStatusBarIconRadioButton.state = NSControlStateValueOn; break;
        case FastmateIconVisibilityBoth: self.showBothRadioButton.state = NSControlStateValueOn; break;
    }
}

- (IBAction)showFastmateRadioButtonSelected:(NSButton *)sender {
    FastmateIconVisibility visibility = sender.tag;
    [[NSUserDefaults standardUserDefaults] setInteger:visibility forKey:@"iconVisibility"];
}

@end

#import "FastmateApplication.h"

@implementation FastmateApplication
@dynamic delegate;

- (void)sendEvent:(NSEvent *)event {
    if (event.type == NSEventTypeKeyDown) {
        if ([self.delegate handleKey:event]) {
            // if the appDelegate handled the key, eat the event
            return;
        }
    }

    [super sendEvent: event];
}

@end

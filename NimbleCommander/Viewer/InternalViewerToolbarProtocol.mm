#include "InternalViewerToolbarProtocol.h"

// this NSToolbarItem descent ensures that it's size is always in-sync with inlayed NSTextField's content width.
// It changes it's .minSize and .maxSize as inserted view notifies that it's stringValue changes
@interface InternalViewerToolbalDynamicSizeLabelItem : NSToolbarItem
@end

@implementation InternalViewerToolbalDynamicSizeLabelItem

- (void) dealloc
{
    [self.view removeObserver:self forKeyPath:@"stringValue"];
    [self.view removeObserver:self forKeyPath:@"controlSize"];
}

- (void) setView:(NSView *)view
{
    [self.view removeObserver:self forKeyPath:@"stringValue"];
    [self.view removeObserver:self forKeyPath:@"controlSize"];
    [view addObserver:self forKeyPath:@"stringValue" options:0 context:NULL];
    [view addObserver:self forKeyPath:@"controlSize" options:0 context:NULL];
    
    [super setView:view];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    static const auto magic_padding_number = 6;
    if( object == self.view )
        if( auto tf = objc_cast<NSTextField>(self.view) ) {
            NSSize sz = [tf.attributedStringValue size];
            self.minSize = NSMakeSize(sz.width + magic_padding_number, self.minSize.height);
            self.maxSize = NSMakeSize(sz.width + magic_padding_number, self.maxSize.height);
        }
}

@end

// Only for IB's sake
@interface InternalViewerToolbarDummyOwner : NSObject<InternalViewerToolbarProtocol>

@property (strong) IBOutlet NSToolbar *internalViewerToolbar;
@property (strong) IBOutlet NSSearchField *internalViewerToolbarSearchField;
@property (strong) IBOutlet NSProgressIndicator *internalViewerToolbarSearchProgressIndicator;
@property (strong) IBOutlet NSPopUpButton *internalViewerToolbarEncodingsPopUp;
@property (strong) IBOutlet NSPopUpButton *internalViewerToolbarModePopUp;
@property (strong) IBOutlet NSButton *internalViewerToolbarPositionButton;
@property (strong) IBOutlet NSTextField *internalViewerToolbarFileSizeLabel;
@property (strong) IBOutlet NSPopover *internalViewerToolbarPopover;
@property (strong) IBOutlet NSButton *internalViewerToolbarWordWrapCheckBox;

@end


@implementation InternalViewerToolbarDummyOwner

- (IBAction)onInternalViewerToolbarSettings:(id)sender{}

@end
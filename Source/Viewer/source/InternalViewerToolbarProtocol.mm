// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "InternalViewerToolbarProtocol.h"
#include <Utility/ObjCpp.h>

// this NSToolbarItem descent ensures that it's size is always in-sync with inlayed NSTextField's content width.
// It changes it's .minSize and .maxSize as inserted view notifies that it's stringValue changes
@interface InternalViewerToolbalDynamicSizeLabelItem : NSToolbarItem
@end

@implementation InternalViewerToolbalDynamicSizeLabelItem

//- (void) dealloc
//{
//    [self.view removeObserver:self forKeyPath:@"stringValue"];
//    [self.view removeObserver:self forKeyPath:@"controlSize"];
//}
//
//- (void) setView:(NSView *)view
//{
//    [self.view removeObserver:self forKeyPath:@"stringValue"];
//    [self.view removeObserver:self forKeyPath:@"controlSize"];
//    [view addObserver:self forKeyPath:@"stringValue" options:0 context:NULL];
//    [view addObserver:self forKeyPath:@"controlSize" options:0 context:NULL];
//
//    [super setView:view];
//}
//
//-(void)observeValueForKeyPath:(NSString *)[[maybe_unused]]keyPath
//                     ofObject:(id)object
//                       change:(NSDictionary *)[[maybe_unused]]change
//                      context:(void *)[[maybe_unused]]context
//{
//    static const auto magic_padding_number = 6;
//    if( object == self.view )
//        if( auto tf = objc_cast<NSTextField>(self.view) ) {
//            NSSize sz = [tf.attributedStringValue size];
//            self.minSize = NSMakeSize(sz.width + magic_padding_number, self.minSize.height);
//            self.maxSize = NSMakeSize(sz.width + magic_padding_number, self.maxSize.height);
//        }
//}

@end

// Only for IB's sake
@interface InternalViewerToolbarDummyOwner : NSObject <InternalViewerToolbarProtocol>

@property(nonatomic) IBOutlet NSToolbar *internalViewerToolbar;
@property(nonatomic) IBOutlet NSSearchField *internalViewerToolbarSearchField;
@property(nonatomic) IBOutlet NSProgressIndicator *internalViewerToolbarSearchProgressIndicator;
@property(nonatomic) IBOutlet NSPopUpButton *internalViewerToolbarEncodingsPopUp;
@property(nonatomic) IBOutlet NSPopUpButton *internalViewerToolbarModePopUp;
@property(nonatomic) IBOutlet NSButton *internalViewerToolbarPositionButton;
@property(nonatomic) IBOutlet NSTextField *internalViewerToolbarFileSizeLabel;
@property(nonatomic) IBOutlet NSPopover *internalViewerToolbarPopover;
@property(nonatomic) IBOutlet NSButton *internalViewerToolbarWordWrapCheckBox;
@property(nonatomic) IBOutlet NSButton *internalViewerToolbarSettingsButton;

@end

@implementation InternalViewerToolbarDummyOwner
@synthesize internalViewerToolbar;
@synthesize internalViewerToolbarSearchField;
@synthesize internalViewerToolbarSearchProgressIndicator;
@synthesize internalViewerToolbarEncodingsPopUp;
@synthesize internalViewerToolbarModePopUp;
@synthesize internalViewerToolbarPositionButton;
@synthesize internalViewerToolbarFileSizeLabel;
@synthesize internalViewerToolbarPopover;
@synthesize internalViewerToolbarWordWrapCheckBox;
@synthesize internalViewerToolbarSettingsButton;

- (IBAction)onInternalViewerToolbarSettings:(id) [[maybe_unused]] _sender
{
}

@end

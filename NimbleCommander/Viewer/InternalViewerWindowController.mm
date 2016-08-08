//
//  InternalViewerWindowController.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 8/4/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#include <Utility/ButtonWithTextColor.h>
#include "../../Files/AppDelegate.h"
#include "BigFileView.h"
#include "InternalViewerController.h"
#include "InternalViewerWindowController.h"

// this NSToolbarItem descent ensures that it's size is always in-sync with inlayed NSTextField's content width.
// It changes it's .minSize and .maxSize as inserted view notifies that it's stringValue changes
@interface InternalViewerWindowController_DynamicSizeToolbarLabelItem : NSToolbarItem
@end

@implementation InternalViewerWindowController_DynamicSizeToolbarLabelItem

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
    static const auto magic_padding_number = 4;
    if( object == self.view )
        if( auto tf = objc_cast<NSTextField>(self.view) ) {
            NSSize sz = [tf.attributedStringValue size];
            self.minSize = NSMakeSize(sz.width + magic_padding_number, self.minSize.height);
            self.maxSize = NSMakeSize(sz.width + magic_padding_number, self.maxSize.height);
        }
}

@end


@interface InternalViewerWindowController ()

@property (strong) IBOutlet BigFileView *viewerView;
@property (strong) IBOutlet NSToolbar *toolbar;
@property (strong) IBOutlet NSSearchField *searchField;
@property (strong) IBOutlet NSProgressIndicator *searchProgressIndicator;
@property (strong) IBOutlet NSPopUpButton *encodingsPopUp;
@property (strong) IBOutlet NSPopUpButton *modePopUp;
@property (strong) IBOutlet ButtonWithTextColor *positionButton;
@property (strong) IBOutlet NSTextField *fileSizeLabel;

@end

@implementation InternalViewerWindowController
{
    InternalViewerController *m_Controller;
    
    
}

- (id) initWithFilepath:(string)path
                     at:(VFSHostPtr)vfs
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if( self ) {
        m_Controller = [[InternalViewerController alloc] init];
        [m_Controller setFile:path at:vfs];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.window.toolbar = self.toolbar;
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    self.positionButton.textColor = NSColor.labelColor;
    
    
    m_Controller.view = self.viewerView;
    m_Controller.searchField = self.searchField;
    m_Controller.searchProgressIndicator = self.searchProgressIndicator;
    m_Controller.encodingsPopUp = self.encodingsPopUp;
    m_Controller.modePopUp = self.modePopUp;
    m_Controller.positionButton = self.positionButton;
    m_Controller.fileSizeLabel = self.fileSizeLabel;
}

- (bool) performBackgrounOpening
{
    return [m_Controller performBackgroundOpening];
}

//[AppDelegate.me addInternalViewerWindow:window];

- (void)showAsFloatingWindow
{
    // this should be called after sucessful finishing of performBackgrounOpening
    [self window];
    [m_Controller show];
    self.viewerView.focusRingType = NSFocusRingTypeNone;
    [AppDelegate.me addInternalViewerWindow:self];
    
    [self showWindow:self];
}

- (void)windowWillClose:(NSNotification *)notification
{
    self.window.delegate = nil;
    dispatch_to_main_queue_after(10ms, [=]{
        [AppDelegate.me removeInternalViewerWindow:self];
    });
}

@end

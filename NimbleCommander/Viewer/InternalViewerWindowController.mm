//
//  InternalViewerWindowController.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 8/4/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#include "../Bootstrap/AppDelegate.h"
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include "BigFileView.h"
#include "InternalViewerController.h"
#include "InternalViewerWindowController.h"

@interface InternalViewerWindow : NSWindow
@end
@implementation InternalViewerWindow
- (void)cancelOperation:(id)sender
{
    [self close];
}
@end

@interface InternalViewerWindowController ()

@property (strong) IBOutlet BigFileView *viewerView;

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

@implementation InternalViewerWindowController
{
    InternalViewerController *m_Controller;
}

@synthesize internalViewerController = m_Controller;

- (id) initWithFilepath:(string)path
                     at:(VFSHostPtr)vfs
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if( self ) {
        m_Controller = [[InternalViewerController alloc] init];
        [m_Controller setFile:path at:vfs];
        
        NSNib *toolbar_nib = [[NSNib alloc] initWithNibNamed:@"InternalViewerToolbar" bundle:nil];
        [toolbar_nib instantiateWithOwner:self topLevelObjects:nil];
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.window.toolbar = self.internalViewerToolbar;
    m_Controller.view = self.viewerView;
    m_Controller.searchField = self.internalViewerToolbarSearchField;
    m_Controller.searchProgressIndicator = self.internalViewerToolbarSearchProgressIndicator;
    m_Controller.encodingsPopUp = self.internalViewerToolbarEncodingsPopUp;
    m_Controller.modePopUp = self.internalViewerToolbarModePopUp;
    m_Controller.positionButton = self.internalViewerToolbarPositionButton;
    m_Controller.fileSizeLabel = self.internalViewerToolbarFileSizeLabel;
    m_Controller.wordWrappingCheckBox = self.internalViewerToolbarWordWrapCheckBox;
    
    m_Controller.nextResponder = self.window.nextResponder;
    self.window.nextResponder = m_Controller;
        
    [self.window bind:@"title" toObject:m_Controller withKeyPath:@"verboseTitle" options:nil];
    GoogleAnalytics::Instance().PostScreenView("File Viewer Window");    
}

- (bool) performBackgrounOpening
{
    return [m_Controller performBackgroundOpening];
}

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
    [m_Controller saveFileState];
    self.window.delegate = nil;
    dispatch_to_main_queue_after(10ms, [=]{
        [AppDelegate.me removeInternalViewerWindow:self];
    });
}

- (void)markInitialSelection:(CFRange)_selection searchTerm:(string)_request
{
    [m_Controller markSelection:_selection forSearchTerm:_request];
}

- (IBAction)onInternalViewerToolbarSettings:(id)sender
{
    [self.internalViewerToolbarPopover showRelativeToRect:objc_cast<NSButton>(sender).bounds
                                                   ofView:objc_cast<NSButton>(sender)
                                            preferredEdge:NSMaxYEdge];
}

- (IBAction)OnFileInternalBigViewCommand:(id)sender
{
    [self close];
}


@end

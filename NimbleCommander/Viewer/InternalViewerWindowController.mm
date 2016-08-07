//
//  InternalViewerWindowController.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 8/4/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#include "../../Files/AppDelegate.h"
#include "BigFileView.h"
#include "InternalViewerController.h"
#include "InternalViewerWindowController.h"

@interface InternalViewerWindowController ()

@property (strong) IBOutlet BigFileView *viewerView;
@property (strong) IBOutlet NSToolbar *toolbar;
@property (strong) IBOutlet NSSearchField *searchField;
@property (strong) IBOutlet NSProgressIndicator *searchProgressIndicator;
@property (strong) IBOutlet NSPopUpButton *encodingsPopUp;
@property (strong) IBOutlet NSPopUpButton *modePopUp;

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
    
    m_Controller.view = self.viewerView;
    m_Controller.searchField = self.searchField;
    m_Controller.searchProgressIndicator = self.searchProgressIndicator;
    m_Controller.encodingsPopUp = self.encodingsPopUp;
    m_Controller.modePopUp = self.modePopUp;
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

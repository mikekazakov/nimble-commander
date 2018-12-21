// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../Bootstrap/AppDelegate.h"
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include "BigFileView.h"
#include "InternalViewerController.h"
#include "InternalViewerWindowController.h"
#include <Habanero/dispatch_cpp.h>
#include <chrono>
#include <Utility/ObjCpp.h>

using namespace std::literals;

@interface InternalViewerWindow : NSWindow
@end
@implementation InternalViewerWindow
- (void)cancelOperation:(id)sender
{
    [self close];
}
@end

@interface InternalViewerWindowController ()

@property (nonatomic) IBOutlet BigFileView *viewerView;
@property (nonatomic) IBOutlet NSToolbar *internalViewerToolbar;
@property (nonatomic) IBOutlet NSSearchField *internalViewerToolbarSearchField;
@property (nonatomic) IBOutlet NSProgressIndicator *internalViewerToolbarSearchProgressIndicator;
@property (nonatomic) IBOutlet NSPopUpButton *internalViewerToolbarEncodingsPopUp;
@property (nonatomic) IBOutlet NSPopUpButton *internalViewerToolbarModePopUp;
@property (nonatomic) IBOutlet NSButton *internalViewerToolbarPositionButton;
@property (nonatomic) IBOutlet NSTextField *internalViewerToolbarFileSizeLabel;
@property (nonatomic) IBOutlet NSPopover *internalViewerToolbarPopover;
@property (nonatomic) IBOutlet NSButton *internalViewerToolbarWordWrapCheckBox;

@end

@implementation InternalViewerWindowController
{
    InternalViewerController *m_Controller;
}

@synthesize internalViewerController = m_Controller;

- (id) initWithFilepath:(std::string)path
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
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    self.window.toolbar = self.internalViewerToolbar;
    self.window.toolbar.visible = true;
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
    GA().PostScreenView("File Viewer Window");    
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
    [NCAppDelegate.me addInternalViewerWindow:self];
    
    [self showWindow:self];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [m_Controller saveFileState];
    self.window.delegate = nil;
    dispatch_to_main_queue_after(10ms, [=]{
        [NCAppDelegate.me removeInternalViewerWindow:self];
    });
}

- (void)markInitialSelection:(CFRange)_selection searchTerm:(std::string)_request
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

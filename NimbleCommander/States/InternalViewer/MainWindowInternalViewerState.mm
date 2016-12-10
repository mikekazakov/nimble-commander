//
//  MainWindowInternalViewerState.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 8/10/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#include "../../Files/MainWindowController.h"
#include "../../Viewer/InternalViewerController.h"
#include "../../Files/GoogleAnalytics.h"
#include "../../Core/ActionsShortcutsManager.h"
#include "MainWindowInternalViewerState.h"

@interface MainWindowInternalViewerState ()

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

@implementation MainWindowInternalViewerState
{    
    InternalViewerController *m_Controller;
}

- (id) init
{
    dispatch_assert_main_queue();
    self = [super initWithNibName:nil bundle:nil];
    if( self ) {
        m_Controller = [[InternalViewerController alloc] init];
        
        NSNib *toolbar_nib = [[NSNib alloc] initWithNibNamed:@"InternalViewerToolbar" bundle:nil];
        [toolbar_nib instantiateWithOwner:self topLevelObjects:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    dispatch_assert_main_queue();    
    [super viewDidLoad];
    // Do view setup here.
    self.view.focusRingType = NSFocusRingTypeNone;
    m_Controller.view = objc_cast<BigFileView>(self.view);
 
    m_Controller.searchField = self.internalViewerToolbarSearchField;
    m_Controller.searchProgressIndicator = self.internalViewerToolbarSearchProgressIndicator;
    m_Controller.encodingsPopUp = self.internalViewerToolbarEncodingsPopUp;
    m_Controller.modePopUp = self.internalViewerToolbarModePopUp;
    m_Controller.positionButton = self.internalViewerToolbarPositionButton;
    m_Controller.fileSizeLabel = self.internalViewerToolbarFileSizeLabel;
    m_Controller.wordWrappingCheckBox = self.internalViewerToolbarWordWrapCheckBox;
    
}

- (NSView*) windowContentView
{
    return self.view;
}

- (NSToolbar*) toolbar
{
    return self.internalViewerToolbar;
}

- (bool) needsWindowTitle
{
    return true;
}

- (bool)openFile:(const string&)_path atVFS:(const VFSHostPtr&)_host;
{
    [m_Controller setFile:_path at:_host];
    return [m_Controller performBackgroundOpening];
//    return [m_Controller performSyncOpening];
}

- (void) Assigned
{
    [self view];
    
    m_Controller.nextResponder = self.view.window.nextResponder;
    self.view.window.nextResponder = m_Controller;
    
    [m_Controller show];
    self.view.window.title = m_Controller.verboseTitle;
//    [self.window makeFirstResponder:m_View];
//    [self UpdateTitle];
    GoogleAnalytics::Instance().PostScreenView("File Viewer State");
}

- (void) Resigned
{
    self.view.window.nextResponder = m_Controller.nextResponder;
    m_Controller.nextResponder = nil;
}

- (void)cancelOperation:(id)sender
{
    dispatch_assert_main_queue();
    [m_Controller saveFileState];
    [m_Controller clear];
    [(MainWindowController*)self.view.window.delegate ResignAsWindowState:self];
}

- (IBAction)OnFileInternalBigViewCommand:(id)sender
{
    [self cancelOperation:sender];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto tag = item.tag;
    IF_MENU_TAG("menu.file.close") {
        item.title = NSLocalizedString(@"Close Viewer", "Menu item title for closing internal viewer state");
        return true;
    }
    return true;
}

- (IBAction)onInternalViewerToolbarSettings:(id)sender
{
    [self.internalViewerToolbarPopover showRelativeToRect:objc_cast<NSButton>(sender).bounds
                                                   ofView:objc_cast<NSButton>(sender)
                                            preferredEdge:NSMaxYEdge];
}

@end

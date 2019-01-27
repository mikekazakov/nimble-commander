// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../Bootstrap/AppDelegate.h"
#include <Utility/CocoaAppearanceManager.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <Viewer/BigFileView.h>
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
@property (nonatomic) IBOutlet NSView *viewerPlaceholder;
@property (nonatomic) BigFileView *viewerView;
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
          viewerFactory:(const std::function<BigFileView*(NSRect)>&)_viewer_factory
             controller:(InternalViewerController*)_controller
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if( self ) {
        m_Controller = _controller;
        [m_Controller setFile:path at:vfs];
        
        NSNib *toolbar_nib = [[NSNib alloc] initWithNibNamed:@"InternalViewerToolbar" bundle:nil];
        [toolbar_nib instantiateWithOwner:self topLevelObjects:nil];
        
        self.viewerView = _viewer_factory(NSMakeRect(0, 0, 100, 100));
        self.viewerView.translatesAutoresizingMaskIntoConstraints = false;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    
    [self.viewerPlaceholder addSubview:self.viewerView];
    auto viewer = self.viewerView;
    const auto views = NSDictionaryOfVariableBindings(viewer);
    const auto constraints = { @"V:|-(==0)-[viewer]-(==0)-|", @"|-(==0)-[viewer]-(==0)-|" };
    for( auto constraint: constraints ) {
        auto constaints = [NSLayoutConstraint constraintsWithVisualFormat:constraint
                                                                  options:0
                                                                  metrics:nil
                                                                    views:views];
        [self.viewerPlaceholder addConstraints:constaints];
    }
    
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

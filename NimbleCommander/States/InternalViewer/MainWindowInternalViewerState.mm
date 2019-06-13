// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include "../MainWindowController.h"
#include <Viewer/ViewerViewController.h>
#include "../../Core/ActionsShortcutsManager.h"
#include "MainWindowInternalViewerState.h"
#include <Habanero/dispatch_cpp.h>
#include <Utility/ObjCpp.h>

@interface MainWindowInternalViewerState ()

@property (nonatomic) IBOutlet NSToolbar *internalViewerToolbar;
@property (nonatomic) IBOutlet NSSearchField *internalViewerToolbarSearchField;
@property (nonatomic) IBOutlet NSProgressIndicator *internalViewerToolbarSearchProgressIndicator;
@property (nonatomic) IBOutlet NSPopUpButton *internalViewerToolbarEncodingsPopUp;
@property (nonatomic) IBOutlet NSPopUpButton *internalViewerToolbarModePopUp;
@property (nonatomic) IBOutlet NSButton *internalViewerToolbarPositionButton;
@property (nonatomic) IBOutlet NSTextField *internalViewerToolbarFileSizeLabel;
@property (nonatomic) IBOutlet NSPopover *internalViewerToolbarPopover;
@property (nonatomic) IBOutlet NSButton *internalViewerToolbarWordWrapCheckBox;
@property (nonatomic) IBOutlet NSButton *internalViewerToolbarSettingsButton;

@property (nonatomic) IBOutlet NCViewerView *embeddedFileView;

@end

@implementation MainWindowInternalViewerState
{    
    NCViewerViewController *m_Controller;
    NSLayoutConstraint         *m_TopLayoutConstraint;    
}

- (id)initWithFrame:(NSRect)_frame_rect
      viewerFactory:(const std::function<NCViewerView*(NSRect)>&)_viewer_factory
         controller:(NCViewerViewController*)_viewer_controller
{
    dispatch_assert_main_queue();
    if( self = [super initWithFrame:_frame_rect] ) {
        self.translatesAutoresizingMaskIntoConstraints = false;
        
        const auto toolbar_bundle =
            [NSBundle bundleWithIdentifier:@"com.magnumbytes.NimbleCommander.Viewer"];
        NSNib *toolbar_nib = [[NSNib alloc] initWithNibNamed:@"InternalViewerToolbar"
                                                      bundle:toolbar_bundle];
        [toolbar_nib instantiateWithOwner:self topLevelObjects:nil];

        auto viewer = _viewer_factory(NSMakeRect(0, 0, 100, 100));
        viewer.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:viewer];
        self.embeddedFileView = viewer;
        
        const auto views = NSDictionaryOfVariableBindings(viewer);
        const auto constraints = {
            @"V:|-(==0@250)-[viewer]-(==0)-|",
            @"|-(==0)-[viewer]-(==0)-|"
        };
        for( auto constraint: constraints )
            [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:constraint
                                                                         options:0
                                                                         metrics:nil
                                                                           views:views]];        
        m_Controller = _viewer_controller;
        [self hookController];
    }
    return self;
}

- (void)hookController
{
    dispatch_assert_main_queue();
    self.embeddedFileView.focusRingType = NSFocusRingTypeNone;
    m_Controller.view = self.embeddedFileView;
    m_Controller.searchField = self.internalViewerToolbarSearchField;
    m_Controller.searchProgressIndicator = self.internalViewerToolbarSearchProgressIndicator;
    m_Controller.encodingsPopUp = self.internalViewerToolbarEncodingsPopUp;
    m_Controller.modePopUp = self.internalViewerToolbarModePopUp;
    m_Controller.positionButton = self.internalViewerToolbarPositionButton;
    m_Controller.fileSizeLabel = self.internalViewerToolbarFileSizeLabel;
    m_Controller.wordWrappingCheckBox = self.internalViewerToolbarWordWrapCheckBox;
    m_Controller.settingsButton = self.internalViewerToolbarSettingsButton;
}

- (NSView*)windowStateContentView
{
    return self;
}

- (NSToolbar*)windowStateToolbar
{
    return self.internalViewerToolbar;
}

- (bool)windowStateNeedsTitle
{
    return true;
}

- (bool)openFile:(const std::string&)_path atVFS:(const VFSHostPtr&)_host
{
    [m_Controller setFile:_path at:_host];
    return [m_Controller performBackgroundOpening];
}

- (void)windowStateDidBecomeAssigned
{
    m_TopLayoutConstraint = [NSLayoutConstraint constraintWithItem:self.embeddedFileView
                                                         attribute:NSLayoutAttributeTop
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:self.window.contentLayoutGuide
                                                         attribute:NSLayoutAttributeTop
                                                        multiplier:1
                                                          constant:0];
    m_TopLayoutConstraint.active = true;
    [self layoutSubtreeIfNeeded];
    
    m_Controller.nextResponder = self.window.nextResponder;
    self.window.nextResponder = m_Controller;
    
    [m_Controller show];
    self.window.title = m_Controller.verboseTitle;
    [self.embeddedFileView.window makeFirstResponder:self.embeddedFileView.keyboardResponder];
    GA().PostScreenView("File Viewer State");
}

- (void)windowStateDidResign
{
    m_TopLayoutConstraint.active = false;
    self.window.nextResponder = m_Controller.nextResponder;
    m_Controller.nextResponder = nil;
}

- (void)cancelOperation:(id)[[maybe_unused]]_sender
{
    dispatch_assert_main_queue();
    [m_Controller saveFileState];
    [m_Controller clear];
    [(NCMainWindowController*)self.window.delegate ResignAsWindowState:self];
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

- (BOOL) isOpaque { return true; }
- (BOOL) wantsUpdateLayer { return true; }
- (void) updateLayer
{
    self.layer.backgroundColor = CurrentTheme().ViewerOverlayColor().CGColor;
}

@end

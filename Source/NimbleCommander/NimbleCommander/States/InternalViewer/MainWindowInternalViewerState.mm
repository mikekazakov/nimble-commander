// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Core/Theming/Theme.h>
#include "../MainWindowController.h"
#include <Viewer/ViewerViewController.h>
#include <Viewer/Bundle.h>
#include "../../Core/ActionsShortcutsManager.h"
#include "MainWindowInternalViewerState.h"
#include <Base/dispatch_cpp.h>
#include <Utility/ObjCpp.h>

@interface MainWindowInternalViewerState ()

@property(nonatomic) IBOutlet NSToolbar *internalViewerToolbar;

@property(nonatomic) IBOutlet NCViewerView *embeddedFileView;

@end

@implementation MainWindowInternalViewerState {
    NCViewerViewController *m_Controller;
    NSLayoutConstraint *m_TopLayoutConstraint;
}
@synthesize internalViewerToolbar;
@synthesize embeddedFileView;

- (id)initWithFrame:(NSRect)_frame_rect
      viewerFactory:(const std::function<NCViewerView *(NSRect)> &)_viewer_factory
         controller:(NCViewerViewController *)_viewer_controller
{
    dispatch_assert_main_queue();
    self = [super initWithFrame:_frame_rect];
    if( self ) {
        self.translatesAutoresizingMaskIntoConstraints = false;

        auto viewer = _viewer_factory(NSMakeRect(0, 0, 100, 100));
        viewer.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:viewer];
        self.embeddedFileView = viewer;

        const auto views = NSDictionaryOfVariableBindings(viewer);
        const auto constraints = {@"V:|-(==0@250)-[viewer]-(==0)-|", @"|-(==0)-[viewer]-(==0)-|"};
        for( auto constraint : constraints )
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
}

- (NSView *)windowStateContentView
{
    return self;
}

- (NSToolbar *)windowStateToolbar
{
    return self.internalViewerToolbar;
}

- (bool)windowStateNeedsTitle
{
    return true;
}

- (bool)openFile:(const std::string &)_path atVFS:(const VFSHostPtr &)_host
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
}

- (void)windowStateDidResign
{
    m_TopLayoutConstraint.active = false;
    self.window.nextResponder = m_Controller.nextResponder;
    m_Controller.nextResponder = nil;
}

- (void)cancelOperation:(id) [[maybe_unused]] _sender
{
    dispatch_assert_main_queue();
    [m_Controller saveFileState];
    [m_Controller clear];
    [static_cast<NCMainWindowController *>(self.window.delegate) ResignAsWindowState:self];
}

- (IBAction)OnFileInternalBigViewCommand:(id)sender
{
    [self cancelOperation:sender];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    auto tag = item.tag;
    IF_MENU_TAG("menu.file.close")
    {
        item.title = NSLocalizedString(@"Close Viewer", "Menu item title for closing internal viewer state");
        return true;
    }
    return true;
}

- (BOOL)isOpaque
{
    return true;
}
- (BOOL)wantsUpdateLayer
{
    return true;
}
- (void)updateLayer
{
    self.layer.backgroundColor = nc::CurrentTheme().ViewerOverlayColor().CGColor;
}

@end

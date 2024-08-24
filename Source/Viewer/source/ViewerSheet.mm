// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ViewerSheet.h"
#include <Viewer/ViewerViewController.h>
#include <Base/dispatch_cpp.h>
#include <Utility/ObjCpp.h>
#include "Internal.h"

using namespace nc::viewer;

@interface NCViewerSheet ()

@property(nonatomic) NCViewerView *view;
@property(nonatomic) IBOutlet NSView *viewPlaceholder;
@property(nonatomic) IBOutlet NSPopover *settingsPopover;

- (IBAction)OnClose:(id)sender;

@end

@implementation NCViewerSheet {
    VFSHostPtr m_VFS;
    std::string m_Path;
    std::unique_ptr<nc::vfs::FileWindow> m_FileWindow;

    NCViewerViewController *m_Controller;
}
@synthesize view;
@synthesize viewPlaceholder;
@synthesize settingsPopover;

- (id)initWithFilepath:(std::string)path
                    at:(VFSHostPtr)vfs
         viewerFactory:(const std::function<NCViewerView *(NSRect)> &)_viewer_factory
      viewerController:(NCViewerViewController *)_viewer_controller
{
    dispatch_assert_main_queue();
    auto nib_path = [Bundle() pathForResource:@"NCViewerSheet" ofType:@"nib"];
    self = [super initWithWindowNibPath:nib_path owner:self];
    if( self ) {
        m_VFS = vfs;
        m_Path = path;

        m_Controller = _viewer_controller;
        [m_Controller setFile:path at:vfs];

        self.view = _viewer_factory(NSMakeRect(0, 0, 100, 100));
        self.view.translatesAutoresizingMaskIntoConstraints = false;
        self.view.focusRingType = NSFocusRingTypeNone;
    }
    return self;
}

- (void)dealloc
{
    dispatch_assert_main_queue();
}

- (bool)open
{
    dispatch_assert_background_queue();

    return [m_Controller performBackgroundOpening];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self.viewPlaceholder addSubview:self.view];
    auto viewer = self.view;
    const auto views = NSDictionaryOfVariableBindings(viewer);
    const auto constraints = {@"V:|-(==0)-[viewer]-(==0)-|", @"|-(==0)-[viewer]-(==0)-|"};
    for( auto constraint : constraints ) {
        auto constaints = [NSLayoutConstraint constraintsWithVisualFormat:constraint options:0 metrics:nil views:views];
        [self.viewPlaceholder addConstraints:constaints];
    }

    self.view.wantsLayer = true; // to reduce side-effects of overdrawing by scrolling with touchpad

    m_Controller.view = self.view;

    [m_Controller show];
    m_Controller.nextResponder = self.window.nextResponder;
    self.window.nextResponder = m_Controller;

    [self.window recalculateKeyViewLoop];
    [self.window makeFirstResponder:self.view.keyboardResponder];
}

- (IBAction)OnClose:(id) [[maybe_unused]] _sender
{
    [m_Controller saveFileState];
    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnFileInternalBigViewCommand:(id) [[maybe_unused]] _sender
{
    [self OnClose:self];
}

- (void)markInitialSelection:(CFRange)_selection searchTerm:(std::string)_request
{
    [m_Controller markSelection:_selection forSearchTerm:_request];
}

- (IBAction)onSettingsClicked:(id)sender
{
    [self.settingsPopover showRelativeToRect:nc::objc_cast<NSButton>(sender).bounds
                                      ofView:nc::objc_cast<NSButton>(sender)
                               preferredEdge:NSMaxYEdge];
}

@end

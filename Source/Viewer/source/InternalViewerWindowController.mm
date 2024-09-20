// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "InternalViewerWindowController.h"
#include <Viewer/ViewerView.h>
#include <Viewer/ViewerViewController.h>
#include <Base/dispatch_cpp.h>
#include <chrono>
#include <Utility/ObjCpp.h>
#include "Internal.h"

using namespace nc::viewer;
using namespace std::literals;

@interface InternalViewerWindow : NSWindow
@end
@implementation InternalViewerWindow
- (void)cancelOperation:(id) [[maybe_unused]] _sender
{
    [self close];
}
@end

@interface InternalViewerWindowController ()
@property(nonatomic) IBOutlet NSView *viewerPlaceholder;
@property(nonatomic) NCViewerView *viewerView;

@end

@implementation InternalViewerWindowController {
    NCViewerViewController *m_Controller;
    __weak id<NCViewerWindowDelegate> m_Delegate;
}
@synthesize internalViewerController = m_Controller;
@synthesize delegate = m_Delegate;
@synthesize viewerPlaceholder;
@synthesize viewerView;

- (id)initWithFilepath:(std::string)path
                    at:(VFSHostPtr)vfs
         viewerFactory:(const std::function<NCViewerView *(NSRect)> &)_viewer_factory
            controller:(NCViewerViewController *)_controller
{
    auto nib_path = [Bundle() pathForResource:@"InternalViewerWindowController" ofType:@"nib"];
    self = [super initWithWindowNibPath:nib_path owner:self];
    if( self ) {
        m_Controller = _controller;
        [m_Controller setFile:path at:vfs];

        self.viewerView = _viewer_factory(NSMakeRect(0, 0, 100, 100));
        self.viewerView.translatesAutoresizingMaskIntoConstraints = false;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [self.viewerPlaceholder addSubview:self.viewerView];
    auto viewer = self.viewerView;
    const auto views = NSDictionaryOfVariableBindings(viewer);
    const auto constraints = {@"V:|-(==0)-[viewer]-(==0)-|", @"|-(==0)-[viewer]-(==0)-|"};
    for( auto constraint : constraints ) {
        auto constaints = [NSLayoutConstraint constraintsWithVisualFormat:constraint options:0 metrics:nil views:views];
        [self.viewerPlaceholder addConstraints:constaints];
    }

    m_Controller.view = self.viewerView;

    m_Controller.nextResponder = self.window.nextResponder;
    self.window.nextResponder = m_Controller;

    [self.window bind:@"title" toObject:m_Controller withKeyPath:@"verboseTitle" options:nil];
}

- (bool)performBackgrounOpening
{
    return [m_Controller performBackgroundOpening];
}

- (void)showAsFloatingWindow
{
    // this should be called after sucessful finishing of performBackgrounOpening
    [self window];
    [m_Controller show];
    self.viewerView.focusRingType = NSFocusRingTypeNone;
    if( const id<NCViewerWindowDelegate> delegate = self.delegate )
        if( [delegate respondsToSelector:@selector(viewerWindowWillShow:)] )
            [delegate viewerWindowWillShow:self];

    [self showWindow:self];
}

- (void)windowWillClose:(NSNotification *) [[maybe_unused]] _notification
{
    [m_Controller saveFileState];
    self.window.delegate = nil;
    dispatch_to_main_queue_after(10ms, [=] {
        if( const id<NCViewerWindowDelegate> delegate = self.delegate )
            if( [delegate respondsToSelector:@selector(viewerWindowWillClose:)] )
                [delegate viewerWindowWillClose:self];
    });
}

- (void)markInitialSelection:(CFRange)_selection searchTerm:(std::string)_request
{
    [m_Controller markSelection:_selection forSearchTerm:_request];
}

- (IBAction)OnFileInternalBigViewCommand:(id) [[maybe_unused]] _sender
{
    [self close];
}

@end

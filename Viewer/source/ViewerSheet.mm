// Copyright (C) 2014-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ViewerSheet.h"
#include <Utility/CocoaAppearanceManager.h>
#include <Viewer/ViewerViewController.h>
#include <Habanero/dispatch_cpp.h>
#include <Utility/ObjCpp.h>

@interface NCViewerSheet ()

@property (nonatomic) NCViewerView *view;
@property (nonatomic) IBOutlet NSView *viewPlaceholder;
@property (nonatomic) IBOutlet NSPopUpButton *mode;
@property (nonatomic) IBOutlet NSTextField *fileSize;
@property (nonatomic) IBOutlet NSButton *filePos;
@property (nonatomic) IBOutlet NSProgressIndicator *searchIndicator;
@property (nonatomic) IBOutlet NSSearchField *searchField;
@property (nonatomic) IBOutlet NSPopover *settingsPopover;
@property (nonatomic) IBOutlet NSPopUpButton *encodings;
@property (nonatomic) IBOutlet NSButton *wordWrap;
@property (nonatomic) IBOutlet NSButton *settingsButton;

- (IBAction)OnClose:(id)sender;


@end

@implementation NCViewerSheet
{
    VFSHostPtr              m_VFS;
    std::string             m_Path;
    std::unique_ptr<nc::vfs::FileWindow> m_FileWindow;
    
    NCViewerViewController *m_Controller;
}

- (id) initWithFilepath:(std::string)path
                     at:(VFSHostPtr)vfs
          viewerFactory:(const std::function<NCViewerView*(NSRect)>&)_viewer_factory
       viewerController:(NCViewerViewController*)_viewer_controller
{
    assert( dispatch_is_main_queue() );
    self = [super init];
    if(self) {
        m_VFS = vfs;
        m_Path = path;
        
        m_Controller = _viewer_controller;
        [m_Controller setFile:path at:vfs];
        
        self.view = _viewer_factory( NSMakeRect(0, 0, 100, 100) );
        self.view.translatesAutoresizingMaskIntoConstraints = false;
    }
    return self;
}

- (void) dealloc
{
    assert( dispatch_is_main_queue() );
}

- (bool) open
{
    assert( !dispatch_is_main_queue() );

    return [m_Controller performBackgroundOpening];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    nc::utility::CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    
    [self.viewPlaceholder addSubview:self.view];
    auto viewer = self.view;
    const auto views = NSDictionaryOfVariableBindings(viewer);
    const auto constraints = { @"V:|-(==0)-[viewer]-(==0)-|", @"|-(==0)-[viewer]-(==0)-|" };
    for( auto constraint: constraints ) {
        auto constaints = [NSLayoutConstraint constraintsWithVisualFormat:constraint
                                                                  options:0
                                                                  metrics:nil
                                                                    views:views];
        [self.viewPlaceholder addConstraints:constaints];
    }
    
    self.view.wantsLayer = true; // to reduce side-effects of overdrawing by scrolling with touchpad

    m_Controller.view = self.view;
    m_Controller.modePopUp = self.mode;
    m_Controller.fileSizeLabel = self.fileSize;
    m_Controller.positionButton = self.filePos;
    m_Controller.searchField = self.searchField;
    m_Controller.searchProgressIndicator = self.searchIndicator;
    m_Controller.encodingsPopUp = self.encodings;
    m_Controller.wordWrappingCheckBox = self.wordWrap;
    m_Controller.settingsButton = self.settingsButton;
    
    [m_Controller show];
    m_Controller.nextResponder = self.window.nextResponder;
    self.window.nextResponder = m_Controller;
    
    [self.window recalculateKeyViewLoop];
    [self.window makeFirstResponder:self.view.keyboardResponder];
}

- (IBAction)OnClose:(id)[[maybe_unused]]_sender
{
    [m_Controller saveFileState];
    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnFileInternalBigViewCommand:(id)[[maybe_unused]]_sender
{
    [self OnClose:self];
}

- (void)markInitialSelection:(CFRange)_selection searchTerm:(std::string)_request
{
    [m_Controller markSelection:_selection forSearchTerm:_request];
}

- (IBAction)onSettingsClicked:(id)sender
{
    [self.settingsPopover showRelativeToRect:objc_cast<NSButton>(sender).bounds
                                      ofView:objc_cast<NSButton>(sender)
                               preferredEdge:NSMaxYEdge];
}

@end

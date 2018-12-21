// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include "BigFileViewSheet.h"
#include "InternalViewerController.h"
#include <Habanero/dispatch_cpp.h>
#include <Utility/ObjCpp.h>

@interface BigFileViewSheet ()

@property (nonatomic) IBOutlet BigFileView *view;

@property (nonatomic) IBOutlet NSPopUpButton *mode;
@property (nonatomic) IBOutlet NSTextField *fileSize;
@property (nonatomic) IBOutlet NSButton *filePos;
@property (nonatomic) IBOutlet NSProgressIndicator *searchIndicator;
@property (nonatomic) IBOutlet NSSearchField *searchField;
@property (nonatomic) IBOutlet NSPopover *settingsPopover;
@property (nonatomic) IBOutlet NSPopUpButton *encodings;
@property (nonatomic) IBOutlet NSButton *wordWrap;

- (IBAction)OnClose:(id)sender;


@end

@implementation BigFileViewSheet
{
    VFSHostPtr              m_VFS;
    std::string             m_Path;
    std::unique_ptr<FileWindow> m_FileWindow;
    
    InternalViewerController *m_Controller;
}

- (id) initWithFilepath:(std::string)path
                     at:(VFSHostPtr)vfs
{
    assert( dispatch_is_main_queue() );
    self = [super init];
    if(self) {
        m_VFS = vfs;
        m_Path = path;
        
        m_Controller = [[InternalViewerController alloc] init];
        [m_Controller setFile:path at:vfs];
        
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
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);

    self.view.hasBorder = true;
    self.view.wantsLayer = true; // to reduce side-effects of overdrawing by scrolling with touchpad

    m_Controller.view = self.view;
    m_Controller.modePopUp = self.mode;
    m_Controller.fileSizeLabel = self.fileSize;
    m_Controller.positionButton = self.filePos;
    m_Controller.searchField = self.searchField;
    m_Controller.searchProgressIndicator = self.searchIndicator;
    m_Controller.encodingsPopUp = self.encodings;
    m_Controller.wordWrappingCheckBox = self.wordWrap;
    
    [m_Controller show];
    m_Controller.nextResponder = self.window.nextResponder;
    self.window.nextResponder = m_Controller;

    GA().PostScreenView("File Viewer Sheet");
}

- (IBAction)OnClose:(id)sender
{
    [m_Controller saveFileState];
    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnFileInternalBigViewCommand:(id)sender
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

//
//  BigFileViewSheet.m
//  Files
//
//  Created by Michael G. Kazakov on 21/09/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "../../Files/ProcessSheetController.h"
#include "../../Files/GoogleAnalytics.h"

#include "BigFileViewSheet.h"

#include "InternalViewerController.h"


// REMOVE THIS DEPENDENCY!!!!!
//#include "../../Files/States/Viewer/MainWindowBigFileViewState.h"
// REMOVE THIS DEPENDENCY!!!!!
//#include "MainWindowBigFileViewState.h"

@interface BigFileViewSheet ()

@property (strong) IBOutlet BigFileView *view;

@property (strong) IBOutlet NSPopUpButton *mode;
@property (strong) IBOutlet NSTextField *fileSize;
@property (strong) IBOutlet NSButton *filePos;
@property (strong) IBOutlet NSProgressIndicator *searchIndicator;
@property (strong) IBOutlet NSSearchField *searchField;
@property (strong) IBOutlet NSPopover *settingsPopover;
@property (strong) IBOutlet NSPopUpButton *encodings;
@property (strong) IBOutlet NSButton *wordWrap;

- (IBAction)OnClose:(id)sender;


@end

@implementation BigFileViewSheet
{
    VFSHostPtr              m_VFS;
    string                  m_Path;
    unique_ptr<FileWindow>  m_FileWindow;
    CFRange                 m_InitialSelection;
    
    
    InternalViewerController *m_Controller;
}

- (id) initWithFilepath:(string)path
                     at:(VFSHostPtr)vfs
{
    
    
    
    self = [super init];
    if(self) {
        m_InitialSelection = CFRangeMake(-1, 0);
        m_VFS = vfs;
        m_Path = path;
        
        m_Controller = [[InternalViewerController alloc] init];
        [m_Controller setFile:path at:vfs];
        
    }
    return self;
}

- (bool) open
{
    assert( !dispatch_is_main_queue() );
    
//    VFSFilePtr origfile;
//    if(m_VFS->CreateFile(m_Path.c_str(), origfile, 0) < 0)
//        return false;
//    
//    VFSFilePtr vfsfile;
//    if(origfile->GetReadParadigm() < VFSFile::ReadParadigm::Random) {
//        // we need to read a file into temporary mem/file storage to access it randomly
//        ProcessSheetController *proc = [ProcessSheetController new];
//        proc.title = NSLocalizedString(@"Opening file...", "Title for process sheet when opening a vfs file");
//        [proc Show];
//                
//        auto wrapper = make_shared<VFSSeqToRandomROWrapperFile>(origfile);
//        int res = wrapper->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock,
//                                [=]{ return proc.userCancelled; },
//                                [=](uint64_t _bytes, uint64_t _total) {
//                                    proc.Progress.doubleValue = double(_bytes) / double(_total);
//                                });
//        [proc Close];
//        if(res != 0)
//            return false;
//        
//        vfsfile = wrapper;
//    }
//    else { // just open input file
//        if(origfile->Open(VFSFlags::OF_Read) < 0)
//            return false;
//        vfsfile = origfile;
//    }
//    
//    m_FileWindow = make_unique<FileWindow>();
//    if(m_FileWindow->OpenFile(vfsfile, MainWindowBigFileViewState.fileWindowSize) != 0)
//        return false;
//    
//    return true;

    return [m_Controller performBackgroundOpening];
}

- (void)windowDidLoad
{
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
    
//    NSString *v = m_Controller.fileSizeLabel.stringValue;
    
//    [self.window.contentView layout];
    
//
//    
//    if( m_InitialSelection.location >= 0 )
//    {
//        self.view.selectionInFile = m_InitialSelection;
//        [self.view ScrollToSelection];
//    }
//    
//    [self.mode selectSegmentWithTag:(int)self.view.mode];
//    for( auto &i: encodings::LiteralEncodingsList() ) {
//        [self.encoding addItemWithTitle: (__bridge NSString*)i.second];
//        self.encoding.lastItem.tag = i.first;
//    }
//  
//    [self.encoding selectItemWithTag:self.view.encoding];

    GoogleAnalytics::Instance().PostScreenView("File View Sheet");
}

- (IBAction)OnClose:(id)sender
{
    [self endSheet:NSModalResponseOK];
}

//- (IBAction)OnMode:(id)sender
//{
//    self.view.mode = (BigFileViewModes)self.mode.selectedSegment;
//}
//
//- (IBAction)OnEncoding:(id)sender
//{
//    self.view.encoding = (int)self.encoding.selectedTag;
//}

- (void) selectBlockAt:(uint64_t)off length:(uint64_t)len
{
    m_InitialSelection = CFRangeMake(off, len);
}

- (IBAction)onSettingsClicked:(id)sender
{
    [self.settingsPopover showRelativeToRect:objc_cast<NSButton>(sender).bounds
                                      ofView:objc_cast<NSButton>(sender)
                               preferredEdge:NSMaxYEdge];
}

@end

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
    
//    [self.view SetFile:m_FileWindow.get()];
  
    [m_Controller show];
    
    
    if( m_InitialSelection.location >= 0 )
    {
        self.view.selectionInFile = m_InitialSelection;
        [self.view ScrollToSelection];
    }
    
    [self.mode selectSegmentWithTag:(int)self.view.mode];
    for( auto &i: encodings::LiteralEncodingsList() ) {
        [self.encoding addItemWithTitle: (__bridge NSString*)i.second];
        self.encoding.lastItem.tag = i.first;
    }
  
    [self.encoding selectItemWithTag:self.view.encoding];

    GoogleAnalytics::Instance().PostScreenView("File View Sheet");
}

- (IBAction)OnClose:(id)sender
{
    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnMode:(id)sender
{
    self.view.mode = (BigFileViewModes)self.mode.selectedSegment;
}

- (IBAction)OnEncoding:(id)sender
{
    self.view.encoding = (int)self.encoding.selectedTag;
}

- (void) selectBlockAt:(uint64_t)off length:(uint64_t)len
{
    m_InitialSelection = CFRangeMake(off, len);
}

@end

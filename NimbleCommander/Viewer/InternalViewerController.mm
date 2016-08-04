#include "../../Files/vfs/VFS.h"
#include "../../Files/ProcessSheetController.h"
#include "../../Files/Config.h"
#include "InternalViewerController.h"

static const auto g_ConfigWindowSize                    = "viewer.fileWindowSize";

@implementation InternalViewerController
{
    string      m_Path;
    VFSHostPtr  m_VFS;
    
    unique_ptr<FileWindow>  m_FileWindow;
    
}

- (void) setFile:(string)path at:(VFSHostPtr)vfs
{
//    dispatch_assert_main_queue();
    // current state checking?
    
    if( path.empty() || !vfs )
        throw logic_error("invalid args for - (void) setFile:(string)path at:(VFSHostPtr)vfs");
    
    m_Path = path;
    m_VFS = vfs;
}


- (bool) performBackgroundOpening
{
    dispatch_assert_background_queue();
    
    VFSFilePtr origfile;
    if( m_VFS->CreateFile(m_Path.c_str(), origfile, 0) < 0 )
        return false;
    
    VFSFilePtr vfsfile;
    if(origfile->GetReadParadigm() < VFSFile::ReadParadigm::Random) {
        // we need to read a file into temporary mem/file storage to access it randomly
        ProcessSheetController *proc = [ProcessSheetController new];
        proc.title = NSLocalizedString(@"Opening file...", "Title for process sheet when opening a vfs file");
        [proc Show];
        
        auto wrapper = make_shared<VFSSeqToRandomROWrapperFile>(origfile);
        int res = wrapper->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock,
                                [=]{ return proc.userCancelled; },
                                [=](uint64_t _bytes, uint64_t _total) {
                                    proc.Progress.doubleValue = double(_bytes) / double(_total);
                                });
        [proc Close];
        if(res != 0)
            return false;
        
        vfsfile = wrapper;
    }
    else { // just open input file
        if(origfile->Open(VFSFlags::OF_Read) < 0)
            return false;
        vfsfile = origfile;
    }
    
    
    auto window = make_unique<FileWindow>();
    if( window->OpenFile(vfsfile, InternalViewerController.fileWindowSize) != 0 )
        return false;
    m_FileWindow = move(window);
    
    return true;
    
}

- (void) show
{
    dispatch_assert_main_queue();
    assert(self.view != nil );
    
    [self.view SetFile:m_FileWindow.get()];
}

+ (unsigned) fileWindowSize
{
    unsigned file_window_size = FileWindow::DefaultWindowSize;
    unsigned file_window_pow2x = GlobalConfig().GetInt(g_ConfigWindowSize);
    if( file_window_pow2x <= 5 )
        file_window_size *= 1 << file_window_pow2x;
    return file_window_size;
}

@end
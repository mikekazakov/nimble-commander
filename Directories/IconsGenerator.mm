//
//  IconsGenerator.cpp
//  Files
//
//  Created by Michael G. Kazakov on 04.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Quartz/Quartz.h>
#import <sys/stat.h>
#import <sys/types.h>
#import <sys/dirent.h>
#import "IconsGenerator.h"
#import "Common.h"

// we need to exclude special types of files, such as fifos, since QLThumbnailImageCreate is very fragile
// and can hang in some cases with that ones
static bool CheckFileIsOK(const char* _s)
{
    struct stat st;
    if( stat(_s, &st) != 0 )
        return false;
    
    return ((st.st_mode & S_IFMT) == S_IFDIR ||
            (st.st_mode & S_IFMT) == S_IFREG  ) &&
            st.st_size > 0;
}

IconsGenerator::IconsGenerator()
{
    m_WorkQueue = dispatch_queue_create("info.filesmanager.Files.IconsGenerator", 0);
    m_IconSize = NSMakeRect(0, 0, 16, 16);
    m_LastIconID = 0;
    m_StopWorkQueue = false;
    m_IconsMode = IconModeFileIconsThumbnails;
    m_UpdateCallback = 0;
    BuildGenericIcons();
}

IconsGenerator::~IconsGenerator()
{
    m_StopWorkQueue++;
    dispatch_sync(m_WorkQueue, ^{});
    if(m_WorkQueue != 0)
        dispatch_release(m_WorkQueue);
}

void IconsGenerator::BuildGenericIcons()
{
    // Load predefined directory icon.
    NSImage *image = [NSImage imageNamed:NSImageNameFolder];
    assert(image);
    m_GenericFolderIcon = [image bestRepresentationForRect:m_IconSize context:nil hints:nil];
    
    // Load predefined generic document file icon.
    image = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
    assert(image);    
    m_GenericFileIcon = [image bestRepresentationForRect:m_IconSize context:nil hints:nil];
}

NSImageRep *IconsGenerator::ImageFor(unsigned _no, VFSListing &_listing)
{
    assert(dispatch_get_current_queue() == dispatch_get_main_queue()); // STA api design
    
    auto &entry = _listing.At(_no);
    if(entry.CIcon() > 0)
    {
        int number = entry.CIcon() - 1;
        const auto it = m_Icons.find(number);
        // sanity check - not founding meta with such number means sanity breach in calling module
        assert(it != m_Icons.end());
        
        const auto &meta = it->second;
        
        if(meta->thumbnail != nil) return meta->thumbnail;
        if(meta->filetype  != nil) return meta->filetype;
        assert(meta->generic != nil);
        return meta->generic;
    }
    
    // no icon - first request for this entry
    // need to collect the appropriate info and put request into generating queue
    
    if(m_LastIconID == MaxIcons)
        return entry.IsDir() ? m_GenericFolderIcon : m_GenericFileIcon; // we're full - sorry

    unsigned short meta_no = m_LastIconID++;
    auto ins_it = m_Icons.insert(std::make_pair( meta_no, std::make_shared<Meta>()));
    assert(ins_it.second == true); // another sanity check
    auto meta = ins_it.first->second;
    
    meta->file_size = entry.Size();
    meta->unix_mode = entry.UnixMode();
    meta->host = _listing.Host();
    char buf[MAXPATHLEN];
    if(!entry.IsDotDot())
        _listing.ComposeFullPathForEntry(_no, buf);
    else
        strcpy(buf, _listing.RelativePath());
    
    meta->relative_path = buf;
    meta->generic = entry.IsDir() ? m_GenericFolderIcon : m_GenericFileIcon;
    meta->extension = entry.HasExtension() ? entry.Extension() : "";
    
    entry.SetCIcon(meta_no+1);
    
    auto sh_this = shared_from_this();
    dispatch_async(m_WorkQueue, ^{
        Runner(meta, sh_this);
    });
    
    return meta->generic;
}

void IconsGenerator::Runner(std::shared_ptr<Meta> _meta, std::shared_ptr<IconsGenerator> _guard)
{
    if(m_StopWorkQueue > 0)
        return;
    
    assert(_meta->thumbnail == nil);
    assert(_meta->filetype  == nil);
    assert(_meta->generic   != nil);
    
    if( strcmp(_meta->host->FSTag(), "native") == 0 )
    {
        // playing inside a real FS, that can be reached via QL framework
        
        // 1st - try to built a real thumbnail
        if(m_IconsMode == IconModeFileIconsThumbnails &&
           (_meta->unix_mode & S_IFMT) != S_IFDIR)
        {
            CGImageRef thumbnail = NULL;

            if(_meta->file_size > 0 &&
               _meta->file_size <= MaxFileSizeForThumbnailNative &&
               CheckFileIsOK(_meta->relative_path.c_str()))
            {
                NSString *item_path = [NSString stringWithUTF8String:_meta->relative_path.c_str()];
                CFURLRef url = CFURLCreateWithFileSystemPath( 0, (CFStringRef) item_path, kCFURLPOSIXPathStyle, false);
                void *keys[] = {(void*)kQLThumbnailOptionIconModeKey};
                void *values[] = {(void*)kCFBooleanTrue};
                static CFDictionaryRef dict = CFDictionaryCreate(CFAllocatorGetDefault(), (const void**)keys, (const void**)values, 1, 0, 0);
                thumbnail = QLThumbnailImageCreate(CFAllocatorGetDefault(), url, m_IconSize.size, dict);
                CFRelease(url);
            }
            
            if(thumbnail != NULL)
            {
                // can we do CGImageRef -> NSImageRep directry?
                _meta->thumbnail = [[NSBitmapImageRep alloc] initWithCGImage:thumbnail];
                CGImageRelease(thumbnail);
                if(m_UpdateCallback)
                    m_UpdateCallback();
            }
        }
        
        if(m_StopWorkQueue > 0)
            return;
        
        if(_meta->thumbnail == nil && m_IconsMode >= IconModeFileIcons)
        {
            NSString *item_path = [NSString stringWithUTF8String:_meta->relative_path.c_str()];
            NSImage *image = [[NSWorkspace sharedWorkspace] iconForFile:item_path];
            _meta->filetype = [image bestRepresentationForRect:m_IconSize context:nil hints:nil];
            
            if(m_UpdateCallback)
                m_UpdateCallback();
        }
    }
    else
    {
        // pure VFS - things are getting funnier here
        // generate icons based on extension for now.
        // pull files into temp dir and set QL on that stuf later
        
        // extract file into temp dir and use QL on it
        if(false &&
           m_IconsMode == IconModeFileIconsThumbnails &&
           (_meta->unix_mode & S_IFMT) != S_IFDIR &&
           _meta->file_size > 0 &&
           _meta->file_size <= MaxFileSizeForThumbnailNonNative &&
           !_meta->extension.empty()
           )
        {
//            MachTimeBenchmark timeb;
            std::shared_ptr<VFSFile> vfs_file;
            if( _meta->host->CreateFile(_meta->relative_path.c_str(), &vfs_file, 0) >= 0)
            {
                if(vfs_file->Open(VFSFile::OF_Read) >= 0)
                {
//                    timeb.Reset("opened vfs file");
                    NSString *temp_dir = NSTemporaryDirectory();
                    assert(temp_dir);
                    char pattern_buf[MAXPATHLEN];
                    sprintf(pattern_buf, "%sinfo.filesmanager.ico.XXXXXX", [temp_dir fileSystemRepresentation]);
//                    sprintf(pattern_buf, "/users/migun/TMPTMPTMPxxxxx");
                    
//                    int fd = open(pattern_buf, O_RDWR | O_TRUNC | O_CREAT);
                    int fd = mkstemp(pattern_buf);
                    if(fd >= 0)
                    {
//                        timeb.Reset("opened tmp file");
                        const size_t bufsz = 256*1024;
                        char buf[bufsz];
                        ssize_t res_read;
                        while( (res_read = vfs_file->Read(buf, bufsz)) > 0 )
                        {
                            ssize_t res_write;
                            while(res_read > 0)
                            {
                                res_write = write(fd, buf, res_read);
                                if(res_write >= 0)
                                    res_read -= res_write;
                                else
                                    goto vfs_to_native_fail;
                            }
                        }
//                        timeb.Reset("written tmp file");
                        
                        vfs_file->Close();
                        close(fd); fd = -1;
//                        timeb.Reset("closed files");
                        
                        char filename_ext[MAXPATHLEN];
                        strcpy(filename_ext, pattern_buf);
                        strcat(filename_ext, ".");
                        strcat(filename_ext, _meta->extension.c_str());
                        
                        if(rename(pattern_buf, filename_ext) == 0)
                        {
//                            timeb.Reset("renamed tmp file");
                            
                            NSString *item_path = [NSString stringWithUTF8String:filename_ext];
                            CFURLRef url = CFURLCreateWithFileSystemPath( 0, (CFStringRef) item_path, kCFURLPOSIXPathStyle, false);
                            void *keys[] = {(void*)kQLThumbnailOptionIconModeKey};
                            void *values[] = {(void*)kCFBooleanTrue};
                            static CFDictionaryRef dict = CFDictionaryCreate(CFAllocatorGetDefault(), (const void**)keys, (const void**)values, 1, 0, 0);
                            CGImageRef thumbnail = QLThumbnailImageCreate(CFAllocatorGetDefault(), url, m_IconSize.size, dict);
                            CFRelease(url);
                            
//                            timeb.Reset("build thumbnail");
                        
                            if(thumbnail != nil)
                            {
                                _meta->thumbnail = [[NSBitmapImageRep alloc] initWithCGImage:thumbnail];
                                CGImageRelease(thumbnail);
                            }
                            unlink(filename_ext);
                        }
                        else
                        {
                            unlink(pattern_buf);
                        }
                        
vfs_to_native_fail:
                        if(fd >= 0)
                        {
                            close(fd);
                            unlink(pattern_buf);
                        }
                    }
                }
            }
        }
        
        
        
        
        
        
        if(!_meta->extension.empty())
        {
            NSString *ext = [NSString stringWithUTF8String:_meta->extension.c_str()];
            NSImage *image = [[NSWorkspace sharedWorkspace] iconForFileType:ext];
            if(image != nil)
            {
                _meta->filetype = [image bestRepresentationForRect:m_IconSize context:nil hints:nil];

                if(m_UpdateCallback)
                    m_UpdateCallback();
            }
        }
        
    }
    
    // clear unnecessary meta data
    std::string().swap(_meta->extension);
    std::string().swap(_meta->relative_path);
    _meta->host.reset();
}

void IconsGenerator::StopWorkQueue()
{
    m_StopWorkQueue++;
    auto sh_this = shared_from_this();
    dispatch_async(m_WorkQueue, ^{
        sh_this->m_StopWorkQueue--; // possible race condition
    });
}

void IconsGenerator::SetIconMode(int _mode)
{
    assert(dispatch_get_current_queue() == dispatch_get_main_queue()); // STA api design
    assert(_mode >= 0 && _mode < IconModesCount);
    m_IconsMode = (IconMode)_mode;
}

void IconsGenerator::Flush()
{
    assert(dispatch_get_current_queue() == dispatch_get_main_queue()); // STA api design
    StopWorkQueue();
    m_Icons.clear();
    m_LastIconID = 0;
}

void IconsGenerator::SetIconSize(int _size)
{
    assert(dispatch_get_current_queue() == dispatch_get_main_queue()); // STA api design    
    if((int)m_IconSize.size.width == _size) return;
    m_IconSize = NSMakeRect(0, 0, _size, _size);
    BuildGenericIcons();    
}

void IconsGenerator::SetUpdateCallback(void (^_cb)())
{
    m_UpdateCallback = _cb;
}

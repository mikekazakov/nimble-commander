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

static const NSString *g_TempDir = NSTemporaryDirectory();

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

static bool IsImageRepEqual(NSBitmapImageRep *_img1, NSBitmapImageRep *_img2)
{
    // compares only NSBitmapImageRep images
    if([_img1 bitmapFormat] != [_img2 bitmapFormat]) return false;
    if([_img1 bitsPerPixel] != [_img2 bitsPerPixel]) return false;
    if([_img1 bytesPerPlane] != [_img2 bytesPerPlane]) return false;
    if([_img1 bytesPerRow] != [_img2 bytesPerRow]) return false;
    if([_img1 isPlanar] != [_img2 isPlanar]) return false;
    if([_img1 numberOfPlanes] != [_img2 numberOfPlanes]) return false;
    if([_img1 samplesPerPixel] != [_img2 samplesPerPixel]) return false;
    
    return memcmp([_img1 bitmapData], [_img2 bitmapData], [_img1 bytesPerPlane]) == 0;
}

static NSImageRep *ProduceThumbnailForVFS(const char *_path,
                                   const char *_ext,
                                   std::shared_ptr<VFSHost> _host,
                                   CGSize _sz)
{
    NSImageRep *result = 0;
    std::shared_ptr<VFSFile> vfs_file;
    if(_host->CreateFile(_path, &vfs_file, 0) < 0)
        return 0;
        
    if(vfs_file->Open(VFSFile::OF_Read) < 0)
        return 0;
    
    char pattern_buf[MAXPATHLEN];
    sprintf(pattern_buf, "%sinfo.filesmanager.ico.XXXXXX", [g_TempDir fileSystemRepresentation]);
    
    int fd = mkstemp(pattern_buf);
    if(fd < 0)
        return 0;
    
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
                goto cleanup;
        }
    }
        
    vfs_file->Close();
    vfs_file.reset();
    close(fd);
    fd = -1;

    char filename_ext[MAXPATHLEN];
    strcpy(filename_ext, pattern_buf);
    strcat(filename_ext, ".");
    strcat(filename_ext, _ext);

    if(rename(pattern_buf, filename_ext) == 0)
    {
        NSString *item_path = [NSString stringWithUTF8String:filename_ext];
        CFURLRef url = CFURLCreateWithFileSystemPath( 0, (CFStringRef) item_path, kCFURLPOSIXPathStyle, false);
        void *keys[] = {(void*)kQLThumbnailOptionIconModeKey};
        void *values[] = {(void*)kCFBooleanTrue};
        static CFDictionaryRef dict = CFDictionaryCreate(CFAllocatorGetDefault(), (const void**)keys, (const void**)values, 1, 0, 0);
        CGImageRef thumbnail = QLThumbnailImageCreate(CFAllocatorGetDefault(), url, _sz, dict);
        CFRelease(url);
                    
        if(thumbnail != nil)
        {
            result = [[NSBitmapImageRep alloc] initWithCGImage:thumbnail];
            CGImageRelease(thumbnail);
        }
        unlink(filename_ext);
    }
    else
    {
        unlink(pattern_buf);
    }
                
cleanup:
    if(fd >= 0)
    {
        close(fd);
        unlink(pattern_buf);
    }

    return result;
}

static NSDictionary *ReadDictionaryFromVFSFile(const char *_path, std::shared_ptr<VFSHost> _host)
{
    std::shared_ptr<VFSFile> vfs_file;
    if(_host->CreateFile(_path, &vfs_file, 0) < 0)
        return 0;
    if(vfs_file->Open(VFSFile::OF_Read) < 0)
        return 0;
    NSData *data = vfs_file->ReadFile();
    vfs_file.reset();
    if(data == 0)
        return 0;
    
    id obj = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:0 error:0];
    if(![obj isKindOfClass:[NSDictionary class]])
        return 0;
    return obj;
}

static NSImage *ReadImageFromVFSFile(const char *_path, std::shared_ptr<VFSHost> _host)
{
    std::shared_ptr<VFSFile> vfs_file;
    if(_host->CreateFile(_path, &vfs_file, 0) < 0)
        return 0;
    if(vfs_file->Open(VFSFile::OF_Read) < 0)
        return 0;
    NSData *data = vfs_file->ReadFile();
    vfs_file.reset();
    if(data == 0)
        return 0;
    
    return [[NSImage alloc] initWithData:data];
}

static NSImageRep *ProduceBundleThumbnailForVFS(const char *_path,
                                      const char *_ext,
                                      std::shared_ptr<VFSHost> _host,
                                      NSRect _rc)
{
    char tmp[MAXPATHLEN];
    strcpy(tmp, _path);
    if(tmp[strlen(tmp)-1] != '/') strcat(tmp, "/");
    strcat(tmp, "Contents/Info.plist");
    
    NSDictionary *plist = ReadDictionaryFromVFSFile(tmp, _host);
    if(!plist)
        return 0;
    
    id icon_id = [plist objectForKey:@"CFBundleIconFile"];
    if(![icon_id isKindOfClass:[NSString class]])
        return 0;
    NSString *icon_str = icon_id;
    
    strcpy(tmp, _path);
    if(tmp[strlen(tmp)-1] != '/') strcat(tmp, "/");
    strcat(tmp, "Contents/Resources/");
    strcat(tmp, [icon_str fileSystemRepresentation]);

    NSImage *image = ReadImageFromVFSFile(tmp, _host);
    if(!image)
        return 0;
    
    return [image bestRepresentationForRect:_rc context:nil hints:nil];
}

IconsGenerator::IconsGenerator()
{
//    m_WorkQueue = dispatch_queue_create("info.filesmanager.Files.IconsGenerator.work_queue", DISPATCH_QUEUE_SERIAL);
    m_ControlQueue = dispatch_queue_create("info.filesmanager.Files.IconsGenerator.control_queue", DISPATCH_QUEUE_SERIAL);
    m_IconsCacheQueue = dispatch_queue_create("info.filesmanager.Files.IconsGenerator.cache_queue", DISPATCH_QUEUE_SERIAL);
    m_WorkGroup = dispatch_group_create();
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
    dispatch_group_wait(m_WorkGroup, DISPATCH_TIME_FOREVER);
    if(m_ControlQueue != 0)
        dispatch_release(m_ControlQueue);
    if(m_WorkGroup != 0)
        dispatch_release(m_WorkGroup);
    if(m_IconsCacheQueue != 0)
        dispatch_release(m_IconsCacheQueue);
}

void IconsGenerator::BuildGenericIcons()
{
    // Load predefined directory icon.
    NSImage *image = [NSImage imageNamed:NSImageNameFolder];
    assert(image);
    m_GenericFolderIconImage = image;
    m_GenericFolderIcon = [image bestRepresentationForRect:m_IconSize context:nil hints:nil];
    m_GenericFolderIconBitmap =  [[NSBitmapImageRep alloc] initWithCGImage:[m_GenericFolderIcon CGImageForProposedRect:0 context:0 hints:0]];
    
    // Load predefined generic document file icon.
    image = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
    assert(image);
    m_GenericFileIconImage = image;
    m_GenericFileIcon = [image bestRepresentationForRect:m_IconSize context:nil hints:nil];
    m_GenericFileIconBitmap =  [[NSBitmapImageRep alloc] initWithCGImage:[m_GenericFileIcon CGImageForProposedRect:0 context:0 hints:0]];
}

NSImageRep *IconsGenerator::ImageFor(unsigned _no, VFSListing &_listing)
{
    assert(dispatch_is_main_queue()); // STA api design
    
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
    if(m_IconsMode >= IconModeFileIcons && !meta->extension.empty())
    {
        __block std::map<std::string, NSImageRep*>::const_iterator it;
        dispatch_sync(m_IconsCacheQueue, ^{ it = m_IconsCache.find(meta->extension); });
        if(it != m_IconsCache.end())
            meta->filetype = it->second;
    }
    
    entry.SetCIcon(meta_no+1);
    
    auto sh_this = shared_from_this();
    dispatch_group_async(m_WorkGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        Runner(meta, sh_this);
    });
    
    return meta->filetype ? meta->filetype : meta->generic;
}

void IconsGenerator::Runner(std::shared_ptr<Meta> _meta, std::shared_ptr<IconsGenerator> _guard)
{
    if(m_StopWorkQueue > 0)
        return;
    
    assert(_meta->thumbnail == nil);
//    assert(_meta->filetype  == nil); // generic may be already set using icons cache
    assert(_meta->generic   != nil);
    
    if(_meta->host->IsNativeFS())
    {
        // playing inside a real FS, that can be reached via QL framework
        
        // zero - if we haven't image for this extension - produce it
        if(!_meta->extension.empty())
        {
            __block std::map<std::string, NSImageRep*>::const_iterator it;
            dispatch_sync(m_IconsCacheQueue, ^{
                it = m_IconsCache.find(_meta->extension);
                if( it == m_IconsCache.end() )
                    m_IconsCache[_meta->extension] = 0; // to exclude parallel image building
            });
            if( it == m_IconsCache.end() )
                if(NSImage *image = [[NSWorkspace sharedWorkspace] iconForFileType:[NSString stringWithUTF8String:_meta->extension.c_str()]])
                { // don't know anything about this extension - ok, ask system
                    auto rep = [image bestRepresentationForRect:m_IconSize context:nil hints:nil];
                    if(!IsImageRepEqual([[NSBitmapImageRep alloc] initWithCGImage:[rep CGImageForProposedRect:0 context:0 hints:0]], m_GenericFileIconBitmap))
                        dispatch_sync(m_IconsCacheQueue, ^{ m_IconsCache[_meta->extension] = rep; });
                }
        }
        
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
                _meta->thumbnail = [[NSBitmapImageRep alloc] initWithCGImage:thumbnail];
                CGImageRelease(thumbnail);
                if(m_UpdateCallback)
                    m_UpdateCallback();
            }
        }
        
        if(m_StopWorkQueue > 0)
            return;
        
        // 2nd - if we haven't built a real thumbnail - try an extention instead
        if(_meta->thumbnail == nil &&
           m_IconsMode >= IconModeFileIcons &&
           CheckFileIsOK(_meta->relative_path.c_str()) // redundant call here. not good.
           )
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
        // special case for for bundles
        if(m_IconsMode == IconModeFileIconsThumbnails &&
           _meta->extension == "app")
        {
            _meta->thumbnail = ProduceBundleThumbnailForVFS(_meta->relative_path.c_str(),
                                                            _meta->extension.c_str(),
                                                            _meta->host,
                                                            m_IconSize);
            if(_meta->thumbnail && m_UpdateCallback)
               m_UpdateCallback();
        }
        
        if(/*false &&*/
           _meta->thumbnail == 0 &&
           m_IconsMode == IconModeFileIconsThumbnails &&
           (_meta->unix_mode & S_IFMT) != S_IFDIR &&
           _meta->file_size > 0 &&
           _meta->file_size <= MaxFileSizeForThumbnailNonNative &&
           !_meta->extension.empty()
           )
        {
            _meta->thumbnail = ProduceThumbnailForVFS(_meta->relative_path.c_str(),
                                                      _meta->extension.c_str(),
                                                      _meta->host,
                                                      m_IconSize.size);
            if(_meta->thumbnail && m_UpdateCallback)
                m_UpdateCallback();
        }
        
        if(!_meta->thumbnail && !_meta->filetype && !_meta->extension.empty())
        {
            // check if have some information in cache
            __block std::map<std::string, NSImageRep*>::const_iterator it;
            dispatch_sync(m_IconsCacheQueue, ^{ it = m_IconsCache.find(_meta->extension); });
            
            if( it != m_IconsCache.end() )
            {
                // ok, just use it. NB! this map can contain zero pointer for the cases when icon is dummy
                _meta->filetype = it->second;
                if(_meta->filetype != 0 && m_UpdateCallback)
                    m_UpdateCallback();
            }
            else
            {
                // don't know anything - ok, ask system
                NSImage *image = [[NSWorkspace sharedWorkspace] iconForFileType:[NSString stringWithUTF8String:_meta->extension.c_str()]];
                if(image != nil)
                {
                    NSImageRep *rep = [image bestRepresentationForRect:m_IconSize context:nil hints:nil];
                    if(IsImageRepEqual([[NSBitmapImageRep alloc] initWithCGImage:[rep CGImageForProposedRect:0 context:0 hints:0]], m_GenericFileIconBitmap))
                    {
                        // dummy icon - this extension has no set icon, so just don't use it
                        dispatch_sync(m_IconsCacheQueue, ^{ m_IconsCache[_meta->extension] = 0; });
                    }
                    else
                    {
                        dispatch_sync(m_IconsCacheQueue, ^{ m_IconsCache[_meta->extension] = rep; });
                        _meta->filetype = rep;
                        if(m_UpdateCallback)
                            m_UpdateCallback();
                    }
                }
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
    dispatch_async(m_ControlQueue, ^{
        dispatch_group_wait(m_WorkGroup, DISPATCH_TIME_FOREVER);
        sh_this->m_StopWorkQueue--; // possible race condition
    });
}

void IconsGenerator::SetIconMode(int _mode)
{
    assert(dispatch_is_main_queue()); // STA api design
    assert(_mode >= 0 && _mode < IconModesCount);
    m_IconsMode = (IconMode)_mode;
}

void IconsGenerator::Flush()
{
    assert(dispatch_is_main_queue()); // STA api design
    StopWorkQueue();
    m_Icons.clear();
    m_LastIconID = 0;
}

void IconsGenerator::SetIconSize(int _size)
{
    assert(dispatch_is_main_queue()); // STA api design
    if((int)m_IconSize.size.width == _size) return;
    m_IconSize = NSMakeRect(0, 0, _size, _size);
    BuildGenericIcons();
    dispatch_sync(m_IconsCacheQueue, ^{ m_IconsCache.clear(); });
}

void IconsGenerator::SetUpdateCallback(void (^_cb)())
{
    m_UpdateCallback = _cb;
}

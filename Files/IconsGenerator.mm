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
#import "QLThumbnailsCache.h"
#import "QLVFSThumbnailsCache.h"
#import "WorkspaceIconsCache.h"
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

static bool IsImageRepEqual(NSBitmapImageRep *_img1, NSBitmapImageRep *_img2)
{
    if(_img1.bitmapFormat != _img2.bitmapFormat) return false;
    if(_img1.bitsPerPixel != _img2.bitsPerPixel) return false;
    if(_img1.bytesPerPlane != _img2.bytesPerPlane) return false;
    if(_img1.bytesPerRow != _img2.bytesPerRow) return false;
    if(_img1.isPlanar != _img2.isPlanar) return false;
    if(_img1.numberOfPlanes != _img2.numberOfPlanes) return false;
    if(_img1.samplesPerPixel != _img2.samplesPerPixel) return false;
    
    return memcmp(_img1.bitmapData, _img2.bitmapData, _img1.bytesPerPlane) == 0;
}

static bool IsImageRepEqual(NSImageRep *_img1, NSBitmapImageRep *_img2)
{
    NSBitmapImageRep *img1 = [[NSBitmapImageRep alloc] initWithCGImage:[_img1 CGImageForProposedRect:0 context:0 hints:0]];
    return IsImageRepEqual(img1, _img2);
}

static NSImageRep *ProduceThumbnailForVFS(const string &_path,
                                   const string &_ext,
                                   const VFSHostPtr &_host,
                                   CGSize _sz)
{
    NSImageRep *result = 0;
    VFSFilePtr vfs_file;
    string filename_ext;
    if(_host->CreateFile(_path.c_str(), vfs_file, 0) < 0)
        return 0;
        
    if(vfs_file->Open(VFSFlags::OF_Read) < 0)
        return 0;
    
    char pattern_buf[MAXPATHLEN];
    sprintf(pattern_buf, "%s" __FILES_IDENTIFIER__ ".ico.XXXXXX", AppTemporaryDirectory().c_str());
    
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

    filename_ext = string(pattern_buf) + "." + _ext;
    if(rename(pattern_buf, filename_ext.c_str()) == 0)
    {
        CFStringRef item_path = (CFStringRef) CFBridgingRetain([NSString stringWithUTF8StdStringNoCopy:filename_ext]);
        CFURLRef url = CFURLCreateWithFileSystemPath(0, item_path, kCFURLPOSIXPathStyle, false);
        static void *keys[] = {(void*)kQLThumbnailOptionIconModeKey};
        static void *values[] = {(void*)kCFBooleanTrue};
        static CFDictionaryRef dict = CFDictionaryCreate(0, (const void**)keys, (const void**)values, 1, 0, 0);
        if(CGImageRef thumbnail = QLThumbnailImageCreate(0, url, _sz, dict))
        {
            result = [[NSBitmapImageRep alloc] initWithCGImage:thumbnail];
            CGImageRelease(thumbnail);
        }

        CFRelease(url);
        CFRelease(item_path);
        unlink(filename_ext.c_str());
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

static NSImageRep *ProduceThumbnailForVFS_Cached(const string &_path, const string &_ext, const VFSHostPtr &_host, CGSize _sz)
{
    // for immutable vfs we can cache generated thumbnails for some time
    pair<bool, NSImageRep *> thumbnail = {false, nil}; // found -> value
    
    if( _host->IsImmutableFS() )
        thumbnail = QLVFSThumbnailsCache::Instance().Get(_path, _host);
    
    if( !thumbnail.first ) {
        thumbnail.second = ProduceThumbnailForVFS(_path, _ext, _host, _sz);
        if( _host->IsImmutableFS() )
            QLVFSThumbnailsCache::Instance().Put(_path, _host, thumbnail.second);
    }
    
    return thumbnail.second;
}

static NSDictionary *ReadDictionaryFromVFSFile(const char *_path, const VFSHostPtr &_host)
{
    VFSFilePtr vfs_file;
    if(_host->CreateFile(_path, vfs_file, 0) < 0)
        return 0;
    if(vfs_file->Open(VFSFlags::OF_Read) < 0)
        return 0;
    NSData *data = vfs_file->ReadFileToNSData();
    vfs_file.reset();
    if(data == 0)
        return 0;
    
    id obj = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:0 error:0];
    return objc_cast<NSDictionary>(obj);
}

static NSImage *ReadImageFromVFSFile(const char *_path, const VFSHostPtr &_host)
{
    VFSFilePtr vfs_file;
    if(_host->CreateFile(_path, vfs_file, 0) < 0)
        return 0;
    if(vfs_file->Open(VFSFlags::OF_Read) < 0)
        return 0;
    NSData *data = vfs_file->ReadFileToNSData();
    vfs_file.reset();
    if(data == 0)
        return 0;
    
    return [[NSImage alloc] initWithData:data];
}

static NSImageRep *ProduceBundleThumbnailForVFS(const string &_path, const VFSHostPtr &_host, NSRect _rc)
{
    NSDictionary *plist = ReadDictionaryFromVFSFile((path(_path) / "Contents/Info.plist").c_str(), _host);
    if(!plist)
        return 0;
    
    auto icon_str = objc_cast<NSString>([plist objectForKey:@"CFBundleIconFile"]);
    if(!icon_str)
        return nil;
    if(!icon_str.fileSystemRepresentation)
        return nil;
    
    path img_path = path(_path) / "Contents/Resources/" / icon_str.fileSystemRepresentation;
    NSImage *image = ReadImageFromVFSFile(img_path.c_str(), _host);
    if(!image)
        return 0;
    
    return [image bestRepresentationForRect:_rc context:nil hints:nil];
}

static NSImageRep *ProduceBundleThumbnailForVFS_Cached(const string &_path, const VFSHostPtr &_host, NSRect _rc)
{
    // for immutable vfs we can cache generated thumbnails for some time
    pair<bool, NSImageRep *> thumbnail = {false, nil}; // found -> value
    
    if( _host->IsImmutableFS() )
        thumbnail = QLVFSThumbnailsCache::Instance().Get(_path, _host);
    
    if( !thumbnail.first ) {
        thumbnail.second = ProduceBundleThumbnailForVFS(_path, _host, _rc);
        if( _host->IsImmutableFS() )
            QLVFSThumbnailsCache::Instance().Put(_path, _host, thumbnail.second);
    }
    
    return thumbnail.second;
}

inline static unsigned MaximumConcurrentRunnersForVFS(const VFSHostPtr &_host)
{
    return _host->IsNativeFS() ? 32 : 6;
}

IconsGenerator::IconsGenerator()
{
    BuildGenericIcons();
}

IconsGenerator::~IconsGenerator()
{
    m_Generation++;
    m_WorkGroup.Wait();
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
    if( entry.CIcon() > 0 ) {
        int number = entry.CIcon() - 1;
        // sanity check - not founding meta with such number means sanity breach in calling module
        assert( number < m_Icons.size() );
        const auto &meta = m_Icons[number];
        
        // check if Icon meta stored here is outdated
        if( meta->file_size == entry.Size() &&
           meta->mtime == entry.MTime() ) {
            
            // short path - return a stored icon from stash
            if(meta->thumbnail != nil)
                return meta->thumbnail;
            if(meta->filetype  != nil)
                return meta->filetype;
            
            assert(meta->generic != nil);
            return meta->generic;
        }
    }
    
    // long path: no icon - first request for this entry (or mb entry changed)
    // need to collect the appropriate info and put request into generating queue
    
    if(m_Icons.size() >= MaxIcons ||
       m_WorkGroup.Count() > MaximumConcurrentRunnersForVFS(_listing.Host()) )
        return entry.IsDir() ? m_GenericFolderIcon : m_GenericFileIcon; // we're full - sorry

    unsigned short meta_no = m_Icons.size();
    m_Icons.emplace_back( make_shared<Meta>() );
    auto meta = m_Icons.back();
    
    meta->file_size = entry.Size();
    meta->unix_mode = entry.UnixMode();
    meta->mtime = entry.MTime();
    meta->host = _listing.Host();
    meta->relative_path = entry.IsDotDot() ?
                        _listing.RelativePath() :
                        _listing.ComposeFullPathForEntry(_no);
    meta->generic = entry.IsDir() ? m_GenericFolderIcon : m_GenericFileIcon;
    meta->extension = entry.HasExtension() ? entry.Extension() : "";
    if(m_IconsMode >= IconMode::Icons && !meta->extension.empty())
    {
        lock_guard<mutex> lock(m_ExtensionIconsCacheLock);
        auto it = m_ExtensionIconsCache.find(meta->extension);
        if(it != end(m_ExtensionIconsCache))
            meta->filetype = it->second;
    }

    // check if we already have thumbnail built
    if(m_IconsMode == IconMode::Thumbnails && meta->host->IsNativeFS())
        if(NSImageRep *th = QLThumbnailsCache::Instance().ThumbnailIfHas(meta->relative_path))
            meta->thumbnail = th;
 
    // check if we already have icon built
    if(m_IconsMode >= IconMode::Icons && meta->host->IsNativeFS())
        if(NSImageRep *th = WorkspaceIconsCache::Instance().IconIfHas(meta->relative_path))
            meta->filetype = th;
        
    entry.SetCIcon(meta_no+1);
    
    m_WorkGroup.Run([=,guard=shared_from_this(),gen=m_Generation.load()]{
        Runner(meta,gen);
    });
    
    if(meta->thumbnail) return meta->thumbnail;
    if(meta->filetype)  return meta->filetype;
    return meta->generic;
}

void IconsGenerator::Runner(shared_ptr<Meta> _meta, unsigned long _my_generation)
{
    if(_my_generation != m_Generation)
        return;
    
//    assert(_meta->thumbnail == nil); // may be already set before
//    assert(_meta->filetype  == nil); // generic may be already set using icons cache
    assert(_meta->generic   != nil);
    
    if(_meta->host->IsNativeFS())
    {
        // playing inside a real FS, that can be reached via QL framework
        
        // zero - if we haven't image for this extension - produce it
        if(!_meta->extension.empty())
        {
            m_ExtensionIconsCacheLock.lock();
            auto it = m_ExtensionIconsCache.find(_meta->extension);
            m_ExtensionIconsCacheLock.unlock();
            
            if( it == end(m_ExtensionIconsCache) ) {
                m_ExtensionIconsCacheLock.lock();
                auto &new_icon = *m_ExtensionIconsCache.emplace(_meta->extension, nil).first; // to exclude parallel image building
                m_ExtensionIconsCacheLock.unlock();
                if(NSImage *image = [NSWorkspace.sharedWorkspace iconForFileType:[NSString stringWithUTF8StdStringNoCopy:_meta->extension]])
                { // don't know anything about this extension - ok, ask system
                    auto rep = [image bestRepresentationForRect:m_IconSize context:nil hints:nil];
                    if(!IsImageRepEqual(rep, m_GenericFileIconBitmap))
                        new_icon.second = rep;
                }
            }
        }
        
        // 1st - try to built a real thumbnail
        if(m_IconsMode == IconMode::Thumbnails &&
           (_meta->unix_mode & S_IFMT) != S_IFDIR &&
           _meta->file_size > 0 &&
           _meta->file_size <= MaxFileSizeForThumbnailNative &&
           CheckFileIsOK(_meta->relative_path.c_str())
           )
        {
            NSImageRep *tn = QLThumbnailsCache::Instance().ProduceThumbnail(_meta->relative_path, m_IconSize.size);
            if(tn != nil && tn != _meta->thumbnail)
            {
                _meta->thumbnail = tn;
                if(m_UpdateCallback)
                    m_UpdateCallback();
            }
        }
        
        if(_my_generation != m_Generation)
            return;
        
        // 2nd - if we haven't built a real thumbnail - try an extention instead
        if(_meta->thumbnail == nil &&
           m_IconsMode >= IconMode::Icons &&
           CheckFileIsOK(_meta->relative_path.c_str()) // possible redundant call here. not good.
           )
        {
            NSImageRep *icon = WorkspaceIconsCache::Instance().ProduceIcon(_meta->relative_path, m_IconSize.size);
            if(icon != nil && icon != _meta->filetype)
            {
                _meta->filetype = icon;
                if(m_UpdateCallback)
                    m_UpdateCallback();
            }
        }
    }
    else
    {
        // special case for for bundles
        if(m_IconsMode == IconMode::Thumbnails &&
           _meta->extension == "app" &&
           _meta->host->ShouldProduceThumbnails())
        {
            _meta->thumbnail = ProduceBundleThumbnailForVFS_Cached(_meta->relative_path, _meta->host, m_IconSize);
            if(_meta->thumbnail && m_UpdateCallback)
               m_UpdateCallback();
        }
        
        if(// false &&
           _meta->thumbnail == 0 &&
           m_IconsMode == IconMode::Thumbnails &&
           (_meta->unix_mode & S_IFMT) != S_IFDIR &&
           _meta->file_size > 0 &&
           _meta->file_size <= MaxFileSizeForThumbnailNonNative &&
           _meta->host->ShouldProduceThumbnails() &&
           !_meta->extension.empty()
           )
        {
            _meta->thumbnail = ProduceThumbnailForVFS_Cached(_meta->relative_path, _meta->extension, _meta->host, m_IconSize.size);
            if(_meta->thumbnail && m_UpdateCallback)
                m_UpdateCallback();
        }
        
        if(!_meta->thumbnail && !_meta->filetype && !_meta->extension.empty())
        {
            // check if have some information in cache
            m_ExtensionIconsCacheLock.lock();
            auto it = m_ExtensionIconsCache.find(_meta->extension);
            m_ExtensionIconsCacheLock.unlock();
            
            if( it != m_ExtensionIconsCache.end() ) {
                // ok, just use it. NB! this map can contain zero pointer for the cases when icon is dummy
                _meta->filetype = it->second;
                if(_meta->filetype != nil && m_UpdateCallback)
                    m_UpdateCallback();
            }
            else { // don't know anything - ok, ask system
                m_ExtensionIconsCacheLock.lock();
                auto &new_icon = *m_ExtensionIconsCache.emplace(_meta->extension, nil).first; // to exclude parallel image building
                m_ExtensionIconsCacheLock.unlock();
                if(NSImage *image = [NSWorkspace.sharedWorkspace iconForFileType:[NSString stringWithUTF8StdStringNoCopy:_meta->extension]]) {
                    NSImageRep *rep = [image bestRepresentationForRect:m_IconSize context:nil hints:nil];
                    if(!IsImageRepEqual(rep, m_GenericFileIconBitmap)) {
                        new_icon.second = rep;
                        _meta->filetype = rep;
                        if(m_UpdateCallback)
                            m_UpdateCallback();
                    }
                }
            }
        }
    }
    
    // clear unnecessary meta data
    _meta->extension.clear();
    _meta->extension.shrink_to_fit();
    _meta->relative_path.clear();
    _meta->relative_path.shrink_to_fit();    
    _meta->host.reset();
}

void IconsGenerator::SetIconMode(IconMode _mode)
{
    assert(dispatch_is_main_queue()); // STA api design
    assert(_mode >= IconMode::Generic && _mode < IconMode::IconModesCount);
    m_IconsMode = _mode;
}

void IconsGenerator::Flush()
{
    assert(dispatch_is_main_queue()); // STA api design
    m_Generation++;
    m_Icons.clear();
}

void IconsGenerator::SetIconSize(int _size)
{
    assert(dispatch_is_main_queue()); // STA api design
    if((int)m_IconSize.size.width == _size) return;
    m_IconSize = NSMakeRect(0, 0, _size, _size);
    BuildGenericIcons();
    lock_guard<mutex> lock(m_ExtensionIconsCacheLock);
    m_ExtensionIconsCache.clear();
}

void IconsGenerator::SetUpdateCallback(function<void()> _cb)
{
    m_UpdateCallback = _cb;
}

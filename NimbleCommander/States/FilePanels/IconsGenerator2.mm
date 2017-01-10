//
//  IconsGenerator.cpp
//  Files
//
//  Created by Michael G. Kazakov on 04.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Quartz/Quartz.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/dirent.h>
#include <Habanero/CommonPaths.h>
#include <NimbleCommander/Core/Caches/QLThumbnailsCache.h>
#include <NimbleCommander/Core/Caches/QLVFSThumbnailsCache.h>
#include <NimbleCommander/Core/Caches/WorkspaceIconsCache.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include "IconsGenerator2.h"

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
    sprintf(pattern_buf, ("%s" + ActivationManager::BundleID() + ".ico.XXXXXX").c_str(), CommonPaths::AppTemporaryDirectory().c_str());
    
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
    return _host->IsNativeFS() ? 64 : 6;
}

inline NSImageRep *IconsGenerator2::IconStorage::Any() const
{
    if(thumbnail)
        return thumbnail;
    if(filetype)
        return filetype;
    return generic;
}

IconsGenerator2::IconsGenerator2()
{
    BuildGenericIcons();
    m_WorkGroup.SetOnDry([=]{
        DrainStash();
    });
}

IconsGenerator2::~IconsGenerator2()
{
    m_Generation++;
    LOCK_GUARD( m_RequestsStashLock ) {
        m_RequestsStash = {};
    }
    m_WorkGroup.SetOnDry( nullptr );
    m_WorkGroup.Wait();
}

void IconsGenerator2::BuildGenericIcons()
{
    // Load predefined directory icon.
    static NSImage *folder_image = [NSImage imageNamed:NSImageNameFolder];
    m_GenericFolderIcon = [folder_image bestRepresentationForRect:NSMakeRect(0, 0, m_IconSize, m_IconSize) context:nil hints:nil];
    m_GenericFolderIconBitmap =  [[NSBitmapImageRep alloc] initWithCGImage:[m_GenericFolderIcon CGImageForProposedRect:0 context:0 hints:0]];
    
    // Load predefined generic document file icon.
    static NSImage *image_file = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
    m_GenericFileIcon = [image_file bestRepresentationForRect:NSMakeRect(0, 0, m_IconSize, m_IconSize) context:nil hints:nil];
    m_GenericFileIconBitmap =  [[NSBitmapImageRep alloc] initWithCGImage:[m_GenericFileIcon CGImageForProposedRect:0 context:0 hints:0]];
}

unsigned short IconsGenerator2::GetSuitablePositionForNewIcon()
{
    if( m_IconsHoles == 0 ) {
        assert( m_Icons.size() < MaxIcons );
        auto n = (unsigned short)m_Icons.size();
        m_Icons.emplace_back( IconStorage() );
        return n;
    }
    else {
        for( auto i = 0, e = (int)m_Icons.size(); i != e; ++i ) {
            if( !m_Icons[i] ) {
                m_Icons[i].emplace();
                --m_IconsHoles;
                return i;
            }
        }
        assert( 0 );
    }
}

NSImageRep *IconsGenerator2::GetGenericIcon( const VFSListingItem &_item ) const
{
    return _item.IsDir() ? m_GenericFolderIcon : m_GenericFileIcon;
}

NSImageRep *IconsGenerator2::GetCachedExtensionIcon( const VFSListingItem &_item) const
{
    if( m_IconsMode < IconMode::Icons )
        return nil;
    
    if( !_item.HasExtension() )
        return nil;

    LOCK_GUARD( m_ExtensionIconsCacheLock ) {
        auto it = m_ExtensionIconsCache.find( _item.Extension() );
        if( it != end(m_ExtensionIconsCache) )
            return it->second;
    }
    
    return nil;
}

bool IconsGenerator2::IsFull() const
{
    return m_Icons.size() - m_IconsHoles >= MaxIcons;
}

bool IconsGenerator2::IsRequestsStashFull() const
{
    int amount = 0;
    LOCK_GUARD(m_RequestsStashLock) {
        amount = (int)m_RequestsStash.size();
    }
    return amount >= MaxStashedRequests;
}

NSImageRep *IconsGenerator2::ImageFor(const VFSListingItem &_item, PanelData::VolatileData &_item_vd)
{
    dispatch_assert_main_queue(); // STA api design
    assert( m_UpdateCallback );
    
    if( _item_vd.icon > 0 ) {
        // short path - we have an already produced icon
        
        int number = _item_vd.icon - 1;
        // sanity check - not founding meta with such number means sanity breach in calling module
        assert( number < m_Icons.size() );
        
        const auto &is = m_Icons[number];
        assert( is );

        return is->Any(); // short path - return a stored icon from stash
        // check if Icon meta stored here is outdated
    }
    
    // long path: no icon - first request for this entry (or mb entry changed)
    // need to collect the appropriate info and put request into generating queue
    
    if( IsFull() || IsRequestsStashFull() ) {
        // we're full - sorry
        
        // but we can try to quickly find an filetype icon
        if( auto icon = GetCachedExtensionIcon(_item) )
            return icon;
        
        // nope, just return a generic icons
        return GetGenericIcon(_item);
    }

    // build IconStorage
    unsigned short is_no = GetSuitablePositionForNewIcon();
    auto &is = *m_Icons[is_no];
    is.file_size = _item.Size();
    is.mtime = _item.MTime();
    is.generic = GetGenericIcon(_item);
    if( auto icon = GetCachedExtensionIcon(_item) )
        is.filetype = icon;

    auto rel_path = _item.IsDotDot() ? _item.Directory() : string(_item.Directory()) + _item.Name();
    bool is_native_fs = _item.Host()->IsNativeFS();
    
    // check if we already have thumbnail built
    if(m_IconsMode == IconMode::Thumbnails && is_native_fs)
        if(NSImageRep *th = QLThumbnailsCache::Instance().ThumbnailIfHas(rel_path))
            is.thumbnail = th;
 
    // check if we already have icon built
    if(m_IconsMode >= IconMode::Icons && is_native_fs)
        if(NSImageRep *th = WorkspaceIconsCache::Instance().IconIfHas(rel_path))
            is.filetype = th;
        
    _item_vd.icon = is_no+1;
    
//  build BuildRequest
    BuildRequest br;
    br.generation = m_Generation;
    br.file_size = is.file_size;
    br.mtime = is.mtime;
    br.unix_mode = _item.UnixMode();
    br.host = _item.Host();
    br.extension = _item.HasExtension() ? _item.Extension() : "";
    br.relative_path = move(rel_path);
    br.filetype = is.filetype;
    br.thumbnail = is.thumbnail;
    br.icon_number = is_no;
    
    RunOrStash( move(br) );

    return is.Any();
}

void IconsGenerator2::RunOrStash( BuildRequest _req )
{
    dispatch_assert_main_queue(); // STA api design
    
    if( m_WorkGroup.Count() <= MaximumConcurrentRunnersForVFS( _req.host )  ) {
        // run task now
        m_WorkGroup.Run([=,request=move(_req)]{
            // went to background worker thread
            BackgroundWork( request );
        });
    }
    else {
        // stash request and fire it group becomes dry
        LOCK_GUARD( m_RequestsStashLock ) {
            m_RequestsStash.emplace( move(_req) );
        }
    }
}

void IconsGenerator2::DrainStash()
{
    // this is a background thread
    LOCK_GUARD( m_RequestsStashLock ) {
        while( !m_RequestsStash.empty() ) {
            if( m_WorkGroup.Count() > MaximumConcurrentRunnersForVFS( m_RequestsStash.front().host ) )
                break; // we load enough of workload
            
            m_WorkGroup.Run([=,request=move(m_RequestsStash.front())] {
                BackgroundWork( request ); // went to background worker thread
            });
            
            m_RequestsStash.pop();
        }
    }
}

void IconsGenerator2::BackgroundWork(const BuildRequest &_request)
{
    if( auto opt_res = Runner(_request) )
        if( _request.generation == m_Generation &&
           (opt_res->filetype || opt_res->thumbnail) )
            dispatch_to_main_queue([=,res=opt_res.value()] {
                // returned to main thread
                
                if( _request.generation != m_Generation )
                    return;
                
                const auto is_no = _request.icon_number;
                assert( is_no < m_Icons.size() ); // consistancy check
                
                if( m_Icons[is_no] ) {
                    if( res.filetype )
                        m_Icons[is_no]->filetype = res.filetype;
                    if( res.thumbnail )
                        m_Icons[is_no]->thumbnail = res.thumbnail;
                    m_UpdateCallback(is_no + 1, m_Icons[is_no]->Any());
                }
            });
}

optional<IconsGenerator2::BuildResult> IconsGenerator2::Runner(const BuildRequest &_req)
{
    if(_req.generation != m_Generation)
        return nullopt;
    
    BuildResult result;
    
    if( _req.host->IsNativeFS() ) {
        // playing inside a real FS, that can be reached via QL framework
        
        // zero - if we haven't image for this extension - produce it
        if( !_req.extension.empty() ) {
            m_ExtensionIconsCacheLock.lock();
            auto it = m_ExtensionIconsCache.find(_req.extension);
            m_ExtensionIconsCacheLock.unlock();
            
            if( it == end(m_ExtensionIconsCache) ) {
                m_ExtensionIconsCacheLock.lock();
                auto &new_icon = *m_ExtensionIconsCache.emplace(_req.extension, nil).first; // to exclude parallel image building
                m_ExtensionIconsCacheLock.unlock();
                if(NSImage *image = [NSWorkspace.sharedWorkspace iconForFileType:[NSString stringWithUTF8StdStringNoCopy:_req.extension]])
                { // don't know anything about this extension - ok, ask system
                    auto rep = [image bestRepresentationForRect:NSMakeRect(0, 0, m_IconSize, m_IconSize) context:nil hints:nil];
                    if(!IsImageRepEqual(rep, m_GenericFileIconBitmap))
                        new_icon.second = rep;
                }
            }
        }
        
        if(_req.generation != m_Generation)
            return nullopt;
        
        // 1st - try to built a real thumbnail
        if(m_IconsMode == IconMode::Thumbnails &&
           (_req.unix_mode & S_IFMT) != S_IFDIR &&
           _req.file_size > 0 &&
           _req.file_size <= MaxFileSizeForThumbnailNative &&
           CheckFileIsOK(_req.relative_path.c_str())
           ) {
            NSImageRep *tn = QLThumbnailsCache::Instance().ProduceThumbnail(_req.relative_path,  NSMakeSize(m_IconSize, m_IconSize));
            if(tn != nil && tn != _req.thumbnail)
                result.thumbnail = tn;
        }
        
        if(_req.generation != m_Generation)
            return nullopt;
        
        // 2nd - if we haven't built a real thumbnail - try an extension instead
        if(_req.thumbnail == nil &&
           m_IconsMode >= IconMode::Icons &&
           CheckFileIsOK(_req.relative_path.c_str()) // possible redundant call here. not good.
           ) {
            NSImageRep *icon = WorkspaceIconsCache::Instance().ProduceIcon(_req.relative_path, NSMakeSize(m_IconSize, m_IconSize));
            if(icon != nil && icon != _req.filetype)
                result.filetype = icon;
        }
    }
    else {
        // special case for for bundles
        if(m_IconsMode == IconMode::Thumbnails &&
           _req.extension == "app" &&
           _req.host->ShouldProduceThumbnails())
            result.thumbnail = ProduceBundleThumbnailForVFS_Cached(_req.relative_path, _req.host, NSMakeRect(0, 0, m_IconSize, m_IconSize));
        
        if(// false &&
           _req.thumbnail == 0 &&
           m_IconsMode == IconMode::Thumbnails &&
           (_req.unix_mode & S_IFMT) != S_IFDIR &&
           _req.file_size > 0 &&
           _req.file_size <= MaxFileSizeForThumbnailNonNative &&
           _req.host->ShouldProduceThumbnails() &&
           !_req.extension.empty() )
            result.thumbnail = ProduceThumbnailForVFS_Cached(_req.relative_path, _req.extension, _req.host, NSMakeSize(m_IconSize, m_IconSize));
        
        if(!_req.thumbnail && !_req.filetype && !_req.extension.empty()) {
            // check if have some information in cache
            m_ExtensionIconsCacheLock.lock();
            auto it = m_ExtensionIconsCache.find(_req.extension);
            m_ExtensionIconsCacheLock.unlock();
            
            if( it != m_ExtensionIconsCache.end() )
                result.filetype = it->second; // ok, just use it. NB! this map can contain zero pointer for the cases when icon is dummy
            else { // don't know anything - ok, ask system
                m_ExtensionIconsCacheLock.lock();
                auto &new_icon = *m_ExtensionIconsCache.emplace(_req.extension, nil).first; // to exclude parallel image building
                m_ExtensionIconsCacheLock.unlock();
                if(NSImage *image = [NSWorkspace.sharedWorkspace iconForFileType:[NSString stringWithUTF8StdStringNoCopy:_req.extension]]) {
                    NSImageRep *rep = [image bestRepresentationForRect:NSMakeRect(0, 0, m_IconSize, m_IconSize) context:nil hints:nil];
                    if(!IsImageRepEqual(rep, m_GenericFileIconBitmap)) {
                        new_icon.second = rep;
                        result.filetype = rep;
                    }
                }
            }
        }
    }
    
    return result;
}

void IconsGenerator2::SetIconMode(IconMode _mode)
{
    assert(dispatch_is_main_queue()); // STA api design
    if( _mode >= IconMode::Generic && _mode < IconMode::IconModesCount )
        m_IconsMode = _mode;
}

void IconsGenerator2::SyncDiscardedAndOutdated( PanelData &_pd )
{
    assert(dispatch_is_main_queue()); // STA api design    
   
    vector<bool> sweep_mark( m_Icons.size(), true );
    vector<int> entries_to_update;
    
    const auto count = (int)_pd.RawEntriesCount();
    for( auto i = 0; i < count; ++i ) {
        auto &vd = _pd.VolatileDataAtRawPosition( i );
        if( vd.icon != 0 ) {
            auto is_no = vd.icon - 1;
            assert( m_Icons[is_no] );
            
            auto item = _pd.EntryAtRawPosition( i );
            
            if(m_Icons[is_no]->file_size != item.Size() &&
               m_Icons[is_no]->mtime != item.MTime() ) {
                // this icon might be outdated, drop it
                vd.icon = 0;
                entries_to_update.emplace_back(i);
            }
            else {
                // this icon is fine
                sweep_mark[is_no] = false;
            }
        }
    }

    for( int i = 0, e = (int)m_Icons.size(); i != e; ++i )
        if( m_Icons[i] && sweep_mark[i] ) {
            m_Icons[i] = nullopt;
            ++m_IconsHoles;
        }
    
    if( m_IconsHoles == m_Icons.size() ) {
        // complete change on data - discard everything and increment generation
        m_Icons.clear();
        m_IconsHoles = 0;
        m_Generation++;
    }
    else {    
        for( auto i: entries_to_update )
            ImageFor( _pd.EntryAtRawPosition(i), _pd.VolatileDataAtRawPosition(i) );
    }
}

void IconsGenerator2::SetIconSize(int _size)
{
    assert(dispatch_is_main_queue()); // STA api design
    if(m_IconSize == _size) return;
    m_IconSize = _size;
    BuildGenericIcons();
    LOCK_GUARD(m_ExtensionIconsCacheLock) {
        m_ExtensionIconsCache.clear();
    }
}

void IconsGenerator2::SetUpdateCallback(function<void(uint16_t, NSImageRep*)> _cb)
{
    assert(dispatch_is_main_queue()); // STA api design
    m_UpdateCallback = move(_cb);
}

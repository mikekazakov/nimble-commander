// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Quartz/Quartz.h>
#include <sys/stat.h>
#include <Habanero/algo.h>
#include "QLThumbnailsCache.h"

QLThumbnailsCache::Key::Key(const string& _p, int _s) :
    path(_p),
    px_size(_s)
{
}

bool QLThumbnailsCache::Key::operator<(const Key& _rhs) const noexcept
{
    return path < _rhs.path ? true : (px_size < _rhs.px_size);
}
    
bool QLThumbnailsCache::Key::operator==(const Key& _rhs) const noexcept
{
    return path == _rhs.path && px_size == _rhs.px_size;
}

QLThumbnailsCache &QLThumbnailsCache::Instance()
{
    static auto inst = make_unique<QLThumbnailsCache>();
    return *inst;
}

static NSImage *BuildRep( const string &_filename, int _px_size )
{
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(nullptr,
                                                           (const UInt8 *)_filename.c_str(),
                                                           _filename.length(),
                                                           false);
    if( url ) {
        static void *keys[] = {(void*)kQLThumbnailOptionIconModeKey};
        static void *values[] = {(void*)kCFBooleanTrue};
        static auto dict = CFDictionaryCreate(0,
                                              (const void**)keys,
                                              (const void**)values,
                                              1,
                                              
                                              0,
                                              0);
        NSImage *result = nil;
        const auto sz = NSMakeSize(_px_size, _px_size);
        if( auto thumbnail = QLThumbnailImageCreate(nullptr,
                                                    url,
                                                    sz,
                                                    dict) ) {
            result = [[NSImage alloc] initWithCGImage:thumbnail
                                                 size:sz];
            CGImageRelease(thumbnail);
        }
        CFRelease(url);
        return result;
    }
    return nil;
}

NSImage *QLThumbnailsCache::ProduceThumbnail(const string &_filename, int _px_size)
{
    m_ItemsLock.lock_shared();
    if( auto i = m_Items.find( {_filename, _px_size} );  i != end(m_Items) ) {
    
        auto [image, mark_as_mru] = CheckCacheAndUpdateIfNeededSharedLocked(_filename, _px_size, i);
        
        m_ItemsLock.unlock_shared();
        
        if( mark_as_mru )
            UpdateAsMRUUnlocked(i);
        
        return image;
    }
    else {
        m_ItemsLock.unlock_shared();
        return ProduceNewAndInsertUnlocked(_filename, _px_size);
    }
}

void QLThumbnailsCache::UpdateAsMRUUnlocked( Container::iterator _it )
{
    lock_guard<spinlock> mru_lock{m_MRULock};
    auto mru_it = find(begin(m_MRU), end(m_MRU), _it);
    assert( mru_it != end(m_MRU) );
    m_MRU.erase(mru_it);
    m_MRU.emplace_back(_it);
}

pair<NSImage *, bool> QLThumbnailsCache::CheckCacheAndUpdateIfNeededSharedLocked(
    const string &_filename, int _px_size, Container::iterator _it)
{
    Info &info = *_it->second;
    bool is_uptodate = false;
    struct stat st;
    if( stat(_filename.c_str(), &st) == 0 ) {
        // check if cache is up-to-date
        if( info.file_size == (uint64_t)st.st_size && info.mtime == (uint64_t)st.st_mtime ) {
            is_uptodate = true;
        }
        else {
            if( !info.is_in_work.test_and_set() ) {
                // we're first to take control of this item
                auto clear_lock = at_scope_end([&]{ info.is_in_work.clear(); });
                if( auto img = BuildRep(_filename, _px_size) ) {
                    info.image = img;
                    info.file_size = st.st_size;
                    info.mtime = st.st_mtime;
                    is_uptodate = true;
                }
            }
            else {
                // item is currently in updating state, let's use current image
            }
        }
    }
    return {info.image, is_uptodate};
}

NSImage *QLThumbnailsCache::ProduceNewAndInsertUnlocked(const string &_filename, int _px_size)
{
    // file must exist and be accessible
    struct stat st;
    if( stat(_filename.c_str(), &st) != 0 )
        return nil;
    
    // insert dummy info into struct, so no one else can try to produce it
    // concurrently - prohibit wasting of resources
    auto info = make_shared<Info>();
    info->file_size = st.st_size;
    info->mtime = st.st_mtime;
    info->image = nil;
    info->is_in_work.test_and_set();
    auto clear_lock = at_scope_end([&]{ info->is_in_work.clear(); });
    
    InsertNewCacheNodeUnlocked(_filename, _px_size, info);
    
    // this operation may be long, not blocking anything for it
    info->image = BuildRep(_filename, _px_size); // img may be nil - it's ok
    
    return info->image;
}

void QLThumbnailsCache::InsertNewCacheNodeUnlocked(
    const string &_filename, int _px_size, const shared_ptr<Info> &_node )
{
    // make sure no one else can access items for writing
    lock_guard<shared_timed_mutex> items_lock{m_ItemsLock};
    
    auto it = m_Items.emplace( Key{_filename, _px_size}, _node ).first;
    
    // make sure no one else access MRU for writing
    lock_guard<spinlock> mru_lock{m_MRULock};
    
    while( m_MRU.size() >= m_CacheSize ) {
        // wipe out old ones if cache is too fat
        m_Items.erase(m_MRU.front());
        m_MRU.pop_front();
    }
    
    m_MRU.emplace_back( it );
}

NSImage *QLThumbnailsCache::ThumbnailIfHas(const string &_filename, int _px_size)
{
    shared_lock<shared_timed_mutex> lock(m_ItemsLock);
    
    auto i = m_Items.find( {_filename, _px_size} );
    if(i != end(m_Items))
        return (*i).second->image;
    return nil;
}

// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Quartz/Quartz.h>
#include <sys/stat.h>
#include <Habanero/algo.h>
#include "QLThumbnailsCache.h"

namespace nc::core {

static inline void hash_combine(size_t& seed)
{
}

template <typename T, typename... Rest>
static inline void hash_combine(size_t& seed, const T& v, Rest... rest) {
    hash<T> hasher;
    seed ^= hasher(v) + 0x9e3779b9 + (seed<<6) + (seed>>2);
    hash_combine(seed, rest...);
}

inline size_t QLThumbnailsCache::KeyHash::operator()(const Key& c) const noexcept
{
    return c.hash;
}

inline QLThumbnailsCache::Key::Key()
{
    static_assert(sizeof(Key) == 56);
    path = path_storage;
    hash_combine(hash, path, px_size);
}

inline QLThumbnailsCache::Key::Key(const Key& _key)
{
    if( _key.path.data() == _key.path_storage.data() ) {
        path_storage = _key.path_storage;
        path = path_storage;
    }
    else {
        assert(_key.path_storage.empty());
        path = _key.path;
    }
    px_size = _key.px_size;
    hash = _key.hash;    
}

QLThumbnailsCache::Key::Key(Key&& _key) noexcept
{
    if( _key.path.data() == _key.path_storage.data() ) {
        path_storage = move(_key.path_storage);
        path = path_storage;
    }
    else {
        assert(_key.path_storage.empty());
        path = _key.path;
    }
    px_size = _key.px_size;
    hash = _key.hash;
}

inline QLThumbnailsCache::Key::Key(string_view _path, int _px_size, no_ownership_tag)
{
    px_size = _px_size;
    path = _path; 
    hash_combine(hash, path, px_size);
}    

inline QLThumbnailsCache::Key::Key(const string& _path, int _px_size)
{
    path_storage = _path;
    px_size = _px_size;
    path = path_storage; 
    hash_combine(hash, path, px_size);
}

QLThumbnailsCache::Key &QLThumbnailsCache::Key::operator=(const Key& _rhs)
{
    if( _rhs.path.data() == _rhs.path_storage.data() ) {
        path_storage = _rhs.path_storage;
        path = path_storage;
    }
    else {
        assert(_rhs.path_storage.empty());
        path = _rhs.path;
        path_storage.clear();
    }
    px_size = _rhs.px_size;
    hash = _rhs.hash;    
    return *this;
}

inline bool QLThumbnailsCache::Key::operator==(const Key& _rhs) const noexcept
{
    return hash == _rhs.hash &&  
           px_size == _rhs.px_size && 
           path == _rhs.path;
}

inline bool QLThumbnailsCache::Key::operator!=(const Key& _rhs) const noexcept
{
    return !(*this == _rhs);
}

QLThumbnailsCache &QLThumbnailsCache::Instance()
{
    static auto inst = make_unique<QLThumbnailsCache>();
    return *inst;
}

static const auto g_QLOptions = []{
    void *keys[] = {(void*)kQLThumbnailOptionIconModeKey};
    void *values[] = {(void*)kCFBooleanTrue}; 
    return CFDictionaryCreate(nullptr,
                              (const void**)keys,
                              (const void**)values,
                              1,
                              nullptr,
                              nullptr);    
}();

static NSImage *BuildRep( const string &_filename, int _px_size )
{
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(nullptr,
                                                           (const UInt8 *)_filename.c_str(),
                                                           _filename.length(),
                                                           false);
    if( url ) {
        NSImage *result = nil;
        const auto sz = NSMakeSize(_px_size, _px_size);
        if( auto thumbnail = QLThumbnailImageCreate(nullptr, url, sz, g_QLOptions) ) {
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
    const auto temp_key = Key{string_view{_filename}, _px_size, Key::no_ownership};    
    auto lock = unique_lock{m_ItemsLock};
    if( m_Items.count(temp_key) ) {
        auto info = m_Items[temp_key]; // acquiring a copy of shared_ptr **by*value**!
        lock.unlock();
        assert( info != nullptr );        
        CheckCacheAndUpdateIfNeeded(_filename, _px_size, *info);
        return info->image;
    }
    else {
        // insert dummy info into the structure, so no one else can try producing it
        // concurrently - prohibit wasting of resources        
        auto key = Key{_filename, _px_size};        
        auto info = make_shared<Info>();
        info->is_in_work.test_and_set();
        m_Items.insert( move(key), info );
        lock.unlock();
        ProduceNew(_filename, _px_size, *info);
        return info->image;
    }
}

void QLThumbnailsCache::CheckCacheAndUpdateIfNeeded(const string &_filename,
                                                    int _px_size,
                                                    Info &_info)
{
    if( _info.is_in_work.test_and_set() == false ) {
        auto clear_lock = at_scope_end([&]{ _info.is_in_work.clear(); });
        // we're first to take control of this item
        
        struct stat st;
        if( stat(_filename.c_str(), &st) != 0 )
            return; // for some reason the file is not accessible - can't do anything
        
        // check if cache is up-to-date
        if( _info.file_size == (uint64_t)st.st_size &&
            _info.mtime == (uint64_t)st.st_mtime ) {
            return; // up-to-date - nothing to do
        }        
        
        if( auto img = BuildRep(_filename, _px_size) ) {
            _info.image = img;
            _info.file_size = st.st_size;
            _info.mtime = st.st_mtime;
        }
    }
    else {
        // the item is currently in updating state, let's use the current image
    }
}

void QLThumbnailsCache::ProduceNew(const string &_filename,
                                   int _px_size,
                                   Info &_info)
{
    assert( _info.is_in_work.test_and_set() == true ); // _info should be locked initially
    auto clear_lock = at_scope_end([&]{ _info.is_in_work.clear(); });
    
    // file must exist and be accessible
    struct stat st;
    if( stat(_filename.c_str(), &st) != 0 )
        return;
    
    _info.file_size = st.st_size;
    _info.mtime = st.st_mtime;    
    _info.image = BuildRep(_filename, _px_size); // img may be nil - it's ok
}

NSImage *QLThumbnailsCache::ThumbnailIfHas(const string &_filename, int _px_size)
{
    const auto temp_key = Key{string_view{_filename}, _px_size, Key::no_ownership};
    auto lock = lock_guard{m_ItemsLock};    
    if( m_Items.count(temp_key) != 0 ) {
        auto &info = m_Items[temp_key];
        assert( info != nullptr );
        return info->image;
    }
    return nil;
}

}

//
//  QLThumbnailsCache.cpp
//  Files
//
//  Created by Michael G. Kazakov on 24.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <Quartz/Quartz.h>
#include <sys/stat.h>
#include <Habanero/algo.h>
#include <Habanero/CFStackAllocator.h>
#include "QLThumbnailsCache.h"

QLThumbnailsCache &QLThumbnailsCache::Instance()
{
    static auto inst = make_unique<QLThumbnailsCache>();
    return *inst;
}

static NSImage *BuildRep( const string &_filename, int _px_size )
{
    CFStackAllocator allocator;
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(allocator.Alloc(),
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
        if( auto thumbnail = QLThumbnailImageCreate(allocator.Alloc(),
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
    
    NSImage *result = nil;
    
    auto i = m_Items.find( {_filename, _px_size} );
    if(i != end(m_Items)) {
        // check what do we have in a cache
        Info &info = *i->second;

        // check if cache is up-to-date
        bool is_uptodate = false;
        struct stat st;
        if(stat(_filename.c_str(), &st) == 0) {
            if( info.file_size == st.st_size &&
                info.mtime == st.st_mtime ) {
                is_uptodate = true;
            }
            else {
                if( !info.is_in_work.test_and_set() ) { // we're first to take control of this item
                    auto clear_lock = at_scope_end([&]{ info.is_in_work.clear(); });
                    if( auto img = BuildRep(_filename, _px_size) ) {
                        info.image = img;
                        info.file_size = st.st_size;
                        info.mtime = st.st_mtime;
                        is_uptodate = true;
                    }
                }
                else { // item is currently in updating state, let's use current image
                    result = info.image;
                }
            }
        }
        
        if(is_uptodate) {
            result = info.image;
            m_ItemsLock.unlock_shared();
            
            // make this item MRU
            LOCK_GUARD( m_MRULock ) {
                auto mru_it = find(begin(m_MRU), end(m_MRU), i);
                assert( mru_it != end(m_MRU) ); // <-- is this happens we're deep in shit, since cache is not well-synchronized and we gonna fuck up soon anyway
                m_MRU.erase(mru_it);
                m_MRU.emplace_back(i);
            }
        }
        else {
            m_ItemsLock.unlock_shared();
        }
    }
    else {
        // build from scratch
        m_ItemsLock.unlock_shared();
        
        // file should exist and be accessible
        struct stat st;
        if( stat(_filename.c_str(), &st) == 0) {
            // insert dummy info into struct, so no one else can try to produce it concurrently - prohibit wasting of resources
            auto info = make_shared<Info>();
            info->file_size = st.st_size;
            info->mtime = st.st_mtime;
            info->image = nil;
            info->is_in_work.test_and_set();
            auto clear_lock = at_scope_end([&]{ info->is_in_work.clear(); });
            
            {
                // put in a cache
                lock_guard<shared_timed_mutex> items_lock(m_ItemsLock); // make sure no one else access items for writing
                auto it = m_Items.emplace( Key{_filename, _px_size}, info ).first;
                // make sure no one else access MRU for writing
                LOCK_GUARD( m_MRULock ) {
                    while( m_MRU.size() >= m_CacheSize ) {
                        // wipe out old ones if cache is too fat
                        m_Items.erase(m_MRU.front());
                        m_MRU.pop_front();
                    }
                    m_MRU.emplace_back( it );
                }
            }
            
            // this operation may be long, not blocking anything for it
            result = BuildRep(_filename, _px_size); // img may be nil - it's ok
            info->image = result;
        }
    }
    return result;
}

NSImage *QLThumbnailsCache::ThumbnailIfHas(const string &_filename, int _px_size)
{
    shared_lock<shared_timed_mutex> lock(m_ItemsLock);
    
    auto i = m_Items.find( {_filename, _px_size} );
    if(i != end(m_Items))
        return (*i).second->image;
    return nil;
}

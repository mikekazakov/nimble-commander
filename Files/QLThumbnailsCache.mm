//
//  QLThumbnailsCache.cpp
//  Files
//
//  Created by Michael G. Kazakov on 24.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <Quartz/Quartz.h>
#include <sys/stat.h>
#include "Common.h"
#include "QLThumbnailsCache.h"

static QLThumbnailsCache *g_Inst;

QLThumbnailsCache::QLThumbnailsCache()
{
}

QLThumbnailsCache::~QLThumbnailsCache()
{
}

QLThumbnailsCache &QLThumbnailsCache::Instance()
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_Inst = new QLThumbnailsCache();
    });
    return *g_Inst;
}

NSImageRep *QLThumbnailsCache::ProduceThumbnail(const string &_filename, CGSize _size)
{
    m_ItemsLock.lock_shared();
    
    NSImageRep *result = nil;
    
    auto i = m_Items.find(_filename);
    if(i != end(m_Items))
    { // check what do we have in a cache
        Info &info = i->second;

        // check if cache is up-to-date
        bool is_uptodate = false;
        struct stat st;
        if(stat(_filename.c_str(), &st) == 0)
        {
            if( i->second.file_size == st.st_size &&
                i->second.mtime == st.st_mtime )
            {
                is_uptodate = true;
            }
            else if(NSImageRep *img = BuildRep(_filename, _size))
            {
                info.image = img;
                info.file_size = st.st_size;
                info.mtime = st.st_mtime;
                is_uptodate = true;
            }
        }
        
        if(is_uptodate)
        {
            result = info.image;
            m_ItemsLock.unlock_shared();
            
            // make this item MRU
            lock_guard<mutex> mru_lock(m_MRULock);
            m_MRU.erase(find(begin(m_MRU), end(m_MRU), i));
            m_MRU.emplace_back(i);
        }
        else
        {
            m_ItemsLock.unlock_shared();
        }
    }
    else
    { // build from scratch
        m_ItemsLock.unlock_shared();
        
        result = BuildRep(_filename, _size); // img may be nil - it's ok
        
        struct stat st;
        if(stat(_filename.c_str(), &st) == 0) // but file should exist and be accessible
        { // put in a cache
        
            lock_guard<mutex> mru_lock(m_MRULock);
            lock_guard<ting::shared_mutex> items_lock(m_ItemsLock);
            
            while(m_MRU.size() >= m_CacheSize)
            { // wipe out old ones if cache is too fat
                m_Items.erase(m_MRU.front());
                m_MRU.pop_front();
            }
            
            auto emp = m_Items.emplace(_filename, Info());
            if(emp.second)
            {
                auto it = emp.first;
                Info &info = it->second;
                info.image = result;
                info.file_size = st.st_size;
                info.mtime = st.st_mtime;
                info.image_size = _size;
            
                m_MRU.emplace_back(it);
            }
        }
    }
    return result;
}

NSImageRep *QLThumbnailsCache::ThumbnailIfHas(const string &_filename)
{
    ting::shared_lock<ting::shared_mutex> lock(m_ItemsLock);
    
    auto i = m_Items.find(_filename);
    if(i != end(m_Items))
        return (*i).second.image;
    return nil;
}

NSImageRep *QLThumbnailsCache::BuildRep(const string &_filename, CGSize _size) const
{
    NSBitmapImageRep *result = nil;
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(0, (const UInt8 *)_filename.c_str(), _filename.length(), false);
    static void *keys[] = {(void*)kQLThumbnailOptionIconModeKey};
    static void *values[] = {(void*)kCFBooleanTrue};
    static CFDictionaryRef dict = CFDictionaryCreate(0, (const void**)keys, (const void**)values, 1, 0, 0);
    if(CGImageRef thumbnail = QLThumbnailImageCreate(0, url, _size, dict))
    {
        result = [[NSBitmapImageRep alloc] initWithCGImage:thumbnail];
        CGImageRelease(thumbnail);
    }
    CFRelease(url);
    
    return result;
}

// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "WorkspaceIconsCacheImpl.h"
#include <sys/stat.h>
#include <Cocoa/Cocoa.h>
#include <Utility/StringExtras.h>

namespace nc::utility {

WorkspaceIconsCacheImpl::WorkspaceIconsCacheImpl()
{        
}
    
WorkspaceIconsCacheImpl::~WorkspaceIconsCacheImpl()
{        
}


NSImage *WorkspaceIconsCacheImpl::IconIfHas(const std::string &_filename)
{
    std::shared_lock<std::shared_timed_mutex> lock(m_ItemsLock);
    
    auto i = m_Items.find(_filename);
    if(i != end(m_Items))
        return (*i).second.image;
    return nil;
}

static NSImage *BuildRep(const std::string &_filename)
{
    return [NSWorkspace.sharedWorkspace iconForFile:[NSString stringWithUTF8StdString:_filename]];
}

NSImage *WorkspaceIconsCacheImpl::ProduceIcon(const std::string &_filename)
{
    m_ItemsLock.lock_shared();
    
    NSImage *result = nil;
    
    auto i = m_Items.find(_filename);
    if(i != end(m_Items))
    { // check what do we have in a cache
        Info &info = i->second;
        
        // check if cache is up-to-date
        bool is_uptodate = false;
        struct stat st;
        if(stat(_filename.c_str(), &st) == 0) {
            if(i->second.file_size == (uint64_t)st.st_size &&
               i->second.mtime == (uint64_t)st.st_mtime &&
               i->second.mode == st.st_mode) {
                is_uptodate = true;
            }
            else if( NSImage *img = BuildRep(_filename) ) {
                info.image = img;
                info.file_size = st.st_size;
                info.mtime = st.st_mtime;
                info.mode = st.st_mode;
                is_uptodate = true;
            }
        }
        
        if(is_uptodate) {
            result = info.image;
            m_ItemsLock.unlock_shared();
            
            // make this item MRU
            std::lock_guard<std::mutex> mru_lock(m_MRULock);
            m_MRU.erase(find(begin(m_MRU), end(m_MRU), i));
            m_MRU.emplace_back(i);
        }
        else {
            m_ItemsLock.unlock_shared();
        }
    }
    else
    { // build from scratch
        m_ItemsLock.unlock_shared();
        
        result = BuildRep( _filename ); // img may be nil - it's ok
        
        struct stat st;
        if(stat(_filename.c_str(), &st) == 0) // but file should exist and be accessible
        { // put in a cache
            
            std::lock_guard<std::mutex> mru_lock(m_MRULock);
            std::lock_guard<std::shared_timed_mutex> items_lock(m_ItemsLock);
            
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
                info.mode = st.st_mode;
                
                m_MRU.emplace_back(it);
            }
        }
    }
    return result;
}

}


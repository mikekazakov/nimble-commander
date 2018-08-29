// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "WorkspaceIconsCacheImpl.h"
#include <sys/stat.h>
#include <Utility/StringExtras.h>
#include <Habanero/algo.h>

namespace nc::utility {

WorkspaceIconsCacheImpl::WorkspaceIconsCacheImpl()
{        
}
    
WorkspaceIconsCacheImpl::~WorkspaceIconsCacheImpl()
{        
}

NSImage *WorkspaceIconsCacheImpl::IconIfHas(const std::string &_file_path)
{
    auto lock = std::lock_guard{m_ItemsLock};
    if( m_Items.count(_file_path) != 0 ) { // O(1)
        auto &info = m_Items[_file_path]; // O(1)
        assert( info != nullptr );
        return info->image;
    }
    return nil;
}

static NSImage *BuildRep(const std::string &_file_path)
{
    static const auto workspace = NSWorkspace.sharedWorkspace; 
    return [workspace iconForFile:[NSString stringWithUTF8StdString:_file_path]];
}

NSImage *WorkspaceIconsCacheImpl::ProduceIcon(const std::string &_file_path)
{
    return Produce(_file_path, std::nullopt);    
}

NSImage *WorkspaceIconsCacheImpl::ProduceIcon(const std::string &_file_path,
                                              const FileStateHint &_state_hint)
{
    return Produce(_file_path, _state_hint);
}
    
NSImage *WorkspaceIconsCacheImpl::Produce(const std::string &_file_path,
                                          std::optional<FileStateHint> _state_hint)
{
    auto lock = std::unique_lock{m_ItemsLock};
    if( m_Items.count(_file_path) ) { // O(1)
        auto info = m_Items[_file_path]; // acquiring a copy of shared_ptr **by*value**! O(1)
        lock.unlock();
        assert( info != nullptr );
        UpdateIfNeeded(_file_path, _state_hint, *info);
        return info->image;
    }
    else {
        // insert dummy info into the structure, so no one else can try producing it
        // concurrently - prohibit wasting of resources                
        auto info = std::make_shared<Info>();
        info->is_in_work.test_and_set();
        m_Items.insert( _file_path, info ); // O(1)
        lock.unlock();
        ProduceNew(_file_path, *info);
        return info->image;
    }
}

static std::optional<WorkspaceIconsCache::FileStateHint>
    ReadFileState(const std::string &_file_path)
{
    struct stat st;
    if( stat(_file_path.c_str(), &st) != 0 )
        return std::nullopt; // for some reason the file is not accessible - can't do anything
    WorkspaceIconsCache::FileStateHint hint;
    hint.size = (uint64_t)st.st_size;
    hint.mtime = (uint64_t)st.st_mtime;
    hint.mode = st.st_mode;      
    return hint;
}

void WorkspaceIconsCacheImpl::UpdateIfNeeded(const std::string &_file_path,
                                             const std::optional<FileStateHint> &_state_hint,
                                             Info &_info)
{
    if( _info.is_in_work.test_and_set() == false ) {
        auto clear_lock = at_scope_end([&]{ _info.is_in_work.clear(); });
        // we're first to take control of this item        
     
        const auto file_state_hint = _state_hint ? _state_hint : ReadFileState(_file_path);
        if( file_state_hint.has_value() == false )
            return; // can't proceed without recent information about the file.        

        // check if cache is up-to-date
        if( _info.file_size == file_state_hint->size &&
           _info.mtime == file_state_hint->mtime &&
           _info.mode == file_state_hint->mode ) {
            return; // is up-to-date => nothing to do
        }        
        
        _info.file_size = file_state_hint->size;
        _info.mtime = file_state_hint->mtime;
        _info.mode = file_state_hint->mode; 
        
        // we prefer to keep the previous version of an icon in case if QL can't produce a new
        // version for the changed file.
        if( auto new_image = BuildRep(_file_path) )
            _info.image = new_image;
    }
    else {
        // the item is currently in updating state, let's use the current image
    }            
}

void WorkspaceIconsCacheImpl::ProduceNew(const std::string &_file_path, Info &_info)
{
    assert( _info.is_in_work.test_and_set() == true ); // _info should be locked initially
    auto clear_lock = at_scope_end([&]{ _info.is_in_work.clear(); });
    
    // file must exist and be accessible
    struct stat st;
    if( stat(_file_path.c_str(), &st) != 0 )
        return;
    
    _info.file_size = st.st_size;
    _info.mtime = st.st_mtime;
    _info.mode = st.st_mode;    
    _info.image = BuildRep(_file_path); // img may be nil - it's ok
}

}

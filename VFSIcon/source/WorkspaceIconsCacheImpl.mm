// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFSIcon/WorkspaceIconsCacheImpl.h>
#include <sys/stat.h>
#include <Utility/StringExtras.h>
#include <Habanero/algo.h>

namespace nc::vfsicon {

WorkspaceIconsCacheImpl::WorkspaceIconsCacheImpl(FileStateReader &_file_state_reader,
                                                 IconBuilder &_icon_builder):
    m_FileStateReader(_file_state_reader),
    m_IconBuilder(_icon_builder)
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

NSImage *WorkspaceIconsCacheImpl::ProduceIcon(const std::string &_file_path)
{
    auto lock = std::unique_lock{m_ItemsLock};
    if( m_Items.count(_file_path) ) { // O(1)
        auto info = m_Items[_file_path]; // acquiring a copy of intrusive_ptr **by*value**! O(1)
        lock.unlock();
        assert( info != nullptr );
        UpdateIfNeeded(_file_path, *info);
        return info->image;
    }
    else {
        // insert dummy info into the structure, so no one else can try producing it
        // concurrently - prohibit wasting of resources                
        auto info = hbn::intrusive_ptr{new Info};
        info->is_in_work.test_and_set();
        m_Items.insert( _file_path, info ); // O(1)
        lock.unlock();
        ProduceNew(_file_path, *info);
        return info->image;
    }  
}

void WorkspaceIconsCacheImpl::UpdateIfNeeded(const std::string &_file_path,
                                             Info &_info)
{
    if( _info.is_in_work.test_and_set() == false ) {
        auto clear_lock = at_scope_end([&]{ _info.is_in_work.clear(); });
        // we're first to take control of this item        
     
        const auto file_state_hint = m_FileStateReader.ReadState(_file_path);
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
        if( auto new_image = m_IconBuilder.Build(_file_path) ) {
            _info.image = new_image;
        }
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
    const auto file_state_hint = m_FileStateReader.ReadState(_file_path);
    if( file_state_hint.has_value() == false )
        return;
    
    _info.file_size = file_state_hint->size;
    _info.mtime = file_state_hint->mtime;
    _info.mode = file_state_hint->mode;
    _info.image = m_IconBuilder.Build(_file_path); // img may be nil - it's ok
}

namespace detail {    

WorkspaceIconsCacheImplBase::FileStateReaderImpl
    WorkspaceIconsCacheImplBase::FileStateReaderImpl::instance;
    
std::optional<WorkspaceIconsCacheImplBase::FileStateHint>
    WorkspaceIconsCacheImplBase::FileStateReaderImpl::ReadState(const std::string &_file_path)
{
    struct stat st;
    if( stat(_file_path.c_str(), &st) != 0 )
        return std::nullopt; // for some reason the file is not accessible - can't do anything
    
    FileStateHint hint;
    hint.size = (uint64_t)st.st_size;
    hint.mtime = (uint64_t)st.st_mtime;
    hint.mode = st.st_mode;      
    return hint;        
}
 
WorkspaceIconsCacheImplBase::IconBuilderImpl
    WorkspaceIconsCacheImplBase::IconBuilderImpl::instance;
    
NSImage *
    WorkspaceIconsCacheImplBase::IconBuilderImpl::Build(const std::string &_file_path)
{
    static const auto workspace = NSWorkspace.sharedWorkspace;
    auto image = [workspace iconForFile:[NSString stringWithUTF8StdString:_file_path]]; 
    return image;
}
    
}

}

#include "BriefOnDiskStorageImpl.h"
#include <Habanero/algo.h>

namespace nc::utility
{
    
BriefOnDiskStorageImpl::BriefOnDiskStorageImpl(const std::string &_base_path,
                                               const std::string &_file_prefix,
                                               hbn::PosixFilesystem &_fs):
    m_BasePath{_base_path},
    m_FilePrefix{_file_prefix},
    m_FS(_fs)
{
    assert( m_BasePath.empty() == false );
    if( m_BasePath.back() != '/' )
        m_BasePath += '/';
}

BriefOnDiskStorageImpl::~BriefOnDiskStorageImpl()
{        
}
    
std::optional<BriefOnDiskStorage::PlacementResult>
    BriefOnDiskStorageImpl::Place(const void *_data, long _bytes)
{
    return PlaceWithExtension(_data, _bytes, "");
}
 
std::optional<BriefOnDiskStorageImpl::PlacementResult>
    BriefOnDiskStorageImpl::PlaceWithExtension(const void *_data,
                                               long _bytes,
                                               const std::string& _extension)
{
    assert(_data != nullptr);
    assert(_bytes >= 0);    
    
    auto filepath = m_BasePath + m_FilePrefix + ".XXXXXX";  
    const auto fd = m_FS.mkstemp(filepath.data());
    if( fd < 0 )
        return std::nullopt;    
    auto on_error_cleanup = at_scope_end([&filepath, this]{ m_FS.unlink(filepath.c_str()); });
    
    {
        auto close_file = at_scope_end([fd, this]{ m_FS.close(fd); });
        auto data_ptr = static_cast<const uint8_t*>(_data);
        while( _bytes > 0 ) {
            const auto write_result = m_FS.write(fd, data_ptr, _bytes);
            if( write_result >= 0 ) {
                _bytes -= write_result;
                data_ptr += write_result; 
            }
            else
                return std::nullopt;
        }
    }
    
    if( _extension.empty() ) {
        auto result = PlacementResult{
            filepath,
            [filepath, fs=&m_FS](){ fs->unlink(filepath.c_str()); }   
        };
        on_error_cleanup.disengage();
        return std::move(result);
    }
    else {
        const auto renamed_filepath = filepath + "." + _extension;
        if( m_FS.rename(filepath.c_str(), renamed_filepath.c_str()) == 0 ) {
            on_error_cleanup.disengage();            
            auto result = PlacementResult{
                renamed_filepath,
                [renamed_filepath, fs=&m_FS]{ fs->unlink(renamed_filepath.c_str()); }
            };
            return std::move(result);            
        }
        else {
            return std::nullopt;
        }
    }
}
    
}

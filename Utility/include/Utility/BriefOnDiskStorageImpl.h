// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "BriefOnDiskStorage.h"
#include <Habanero/PosixFilesystemImpl.h>

namespace nc::utility
{
    
class BriefOnDiskStorageImpl final : public BriefOnDiskStorage 
{
public:
    BriefOnDiskStorageImpl(const std::string &_base_path,
                           const std::string &_file_prefix = "",
                           hbn::PosixFilesystem &_fs = hbn::PosixFilesystemImpl::instance);
    ~BriefOnDiskStorageImpl();
    
    std::optional<PlacementResult> Place(const void *_data, long _bytes) override;    
    
    std::optional<PlacementResult> PlaceWithExtension(const void *_data,
                                                      long _bytes,
                                                      const std::string& _extension) override;
    
private:
    std::string m_BasePath;
    std::string m_FilePrefix;
    hbn::PosixFilesystem &m_FS;
};

}

// Copyright (C) 2018-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "BriefOnDiskStorage.h"
#include <Base/PosixFilesystemImpl.h>

namespace nc::utility {

class BriefOnDiskStorageImpl final : public BriefOnDiskStorage
{
public:
    BriefOnDiskStorageImpl(const std::string &_base_path,
                           const std::string &_file_prefix = "",
                           base::PosixFilesystem &_fs = base::PosixFilesystemImpl::instance);
    ~BriefOnDiskStorageImpl();

    std::optional<PlacementResult> Place(const void *_data, long _bytes) override;

    std::optional<PlacementResult>
    PlaceWithExtension(const void *_data, long _bytes, const std::string &_extension) override;

private:
    std::string m_BasePath;
    std::string m_FilePrefix;
    base::PosixFilesystem &m_FS;
};

} // namespace nc::utility

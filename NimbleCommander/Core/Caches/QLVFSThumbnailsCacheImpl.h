// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "QLVFSThumbnailsCache.h"
#include <Utility/BriefOnDiskStorage.h>

namespace nc::utility {
    
class QLVFSThumbnailsCacheImpl : public QLVFSThumbnailsCache
{
public:
    QLVFSThumbnailsCacheImpl(const std::shared_ptr<BriefOnDiskStorage> &_temp_storage);
    ~QLVFSThumbnailsCacheImpl();
    
    NSImage * ProduceFileThumbnail(const std::string &_file_path,
                                  VFSHost &_host,
                                  int _px_size) override;
    
    NSImage * ProduceBundleThumbnail(const std::string &_file_path,
                                    VFSHost &_host,
                                    int _px_size) override;

private:
    NSImage *ProduceThumbnail(const string &_path,
                              const string &_ext,
                              VFSHost &_host,
                              CGSize _sz);

    std::shared_ptr<BriefOnDiskStorage> m_TempStorage;    
};
    
}

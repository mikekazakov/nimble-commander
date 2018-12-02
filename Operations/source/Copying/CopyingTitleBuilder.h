// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "Options.h"

namespace nc::ops {

class CopyingTitleBuilder
{
public:
    CopyingTitleBuilder(const std::vector<VFSListingItem> &_source_files,
                        const std::string& _destination_path,
                        const CopyingOptions &_options);

    std::string TitleForPreparing() const;
    std::string TitleForProcessing() const;
    std::string TitleForVerifying() const;
    std::string TitleForCleanup() const;

private:
    const std::vector<VFSListingItem> &m_SourceFiles;
    const std::string& m_DestinationPath;
    const CopyingOptions &m_Options;
};


}

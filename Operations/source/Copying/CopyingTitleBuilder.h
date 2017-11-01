#pragma once

#include <VFS/VFS.h>
#include "Options.h"

namespace nc::ops {

class CopyingTitleBuilder
{
public:
    CopyingTitleBuilder(const vector<VFSListingItem> &_source_files,
                        const string& _destination_path,
                        const CopyingOptions &_options);

    string TitleForPreparing() const;
    string TitleForProcessing() const;
    string TitleForVerifying() const;
    string TitleForCleanup() const;

private:
    const vector<VFSListingItem> &m_SourceFiles;
    const string& m_DestinationPath;
    const CopyingOptions &m_Options;
};


}

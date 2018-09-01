// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "BriefOnDiskStorage.h"

namespace nc::utility
{

BriefOnDiskStorage::PlacementResult::PlacementResult(std::string _path,
                                                     std::function<void()> _cleanup) noexcept:
    m_Path(std::move(_path)),
    m_Cleanup(std::move(_cleanup))
{
    assert(m_Path.empty() == false);
    assert(m_Cleanup != nullptr);
}

BriefOnDiskStorage::PlacementResult::PlacementResult(PlacementResult&& _pr) noexcept:
    m_Path(std::move(_pr.m_Path)),
    m_Cleanup(std::move(_pr.m_Cleanup))
{
}
    
BriefOnDiskStorage::PlacementResult::~PlacementResult() noexcept
{
    if( m_Cleanup ) {
        try {
            m_Cleanup();
        }
        catch(...) {
        }
    }
}
    
const std::string &BriefOnDiskStorage::PlacementResult::Path() const noexcept
{
    return m_Path;
}
    
}

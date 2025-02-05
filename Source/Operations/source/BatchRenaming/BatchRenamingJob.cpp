// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "BatchRenamingJob.h"
#include <Utility/StringExtras.h>

namespace nc::ops {

BatchRenamingJob::BatchRenamingJob(std::vector<std::string> _src_paths,
                                   std::vector<std::string> _dst_paths,
                                   std::shared_ptr<VFSHost> _vfs)
    : m_Source(std::move(_src_paths)), m_Destination(std::move(_dst_paths)), m_VFS(_vfs)
{
    assert(m_Source.size() == m_Destination.size());
    Statistics().SetPreferredSource(Statistics::SourceType::Items);
}

BatchRenamingJob::~BatchRenamingJob() = default;

void BatchRenamingJob::Perform()
{
    Statistics().CommitEstimated(Statistics::SourceType::Items, m_Source.size());

    for( int i = 0, e = static_cast<int>(m_Source.size()); i != e; ++i ) {
        if( BlockIfPaused(); IsStopped() )
            return;

        Rename(m_Source[i], m_Destination[i]);
    }
}

void BatchRenamingJob::Rename(const std::string &_src, const std::string &_dst)
{
    if( _src == _dst ) {
        Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
        return;
    }

    while( true ) {
        const bool dst_exists = m_VFS->Exists(_dst);

        std::expected<void, Error> rc;
        if( dst_exists && !LowercaseEqual(_src, _dst) )
            rc = std::unexpected(Error{Error::POSIX, EEXIST});
        else
            rc = m_VFS->Rename(_src, _dst);

        if( rc )
            break;

        switch( m_OnRenameError(rc.error(), _dst, *m_VFS) ) {
            case RenameErrorResolution::Skip:
                Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
                return;
            case RenameErrorResolution::Stop:
                Stop();
                return;
            case RenameErrorResolution::Retry:
                continue;
        }
    }

    Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
}

} // namespace nc::ops

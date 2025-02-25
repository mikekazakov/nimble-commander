// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DirectoryCreationJob.h"

namespace nc::ops {

static const auto g_CreateMode = 0755;

DirectoryCreationJob::DirectoryCreationJob(const std::vector<std::string> &_directories_chain,
                                           const std::string &_root_folder,
                                           const VFSHostPtr &_vfs)
    : m_DirectoriesChain(_directories_chain), m_RootFolder(_root_folder), m_VFS(_vfs)
{
    Statistics().SetPreferredSource(Statistics::SourceType::Items);
}

DirectoryCreationJob::~DirectoryCreationJob() = default;

void DirectoryCreationJob::Perform()
{
    Statistics().CommitEstimated(Statistics::SourceType::Items, m_DirectoriesChain.size());

    std::filesystem::path p = m_RootFolder;
    for( auto &s : m_DirectoriesChain ) {
        if( BlockIfPaused(); IsStopped() )
            return;

        p /= s;
        if( !MakeDir(p.native()) )
            return;

        Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
    }
}

bool DirectoryCreationJob::MakeDir(const std::string &_path)
{
    while( true ) {
        const std::expected<VFSStat, Error> st = m_VFS->Stat(_path, 0);
        if( !st )
            break;
        if( st->mode_bits.dir ) {
            return true;
        }
        else {
            switch( m_OnError(Error{Error::POSIX, EEXIST}, _path, *m_VFS) ) {
                case ErrorResolution::Retry:
                    continue;
                default:
                    Stop();
                    return false;
            }
        }
    }

    while( true ) {
        const std::expected<void, Error> mkdir_rc = m_VFS->CreateDirectory(_path, g_CreateMode);
        if( mkdir_rc )
            return true;
        switch( m_OnError(mkdir_rc.error(), _path, *m_VFS) ) {
            case ErrorResolution::Retry:
                continue;
            default:
                Stop();
                return false;
        }
    }
    return true;
}

} // namespace nc::ops

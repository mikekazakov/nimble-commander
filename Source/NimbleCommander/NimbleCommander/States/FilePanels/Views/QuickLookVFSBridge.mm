// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "QuickLookVFSBridge.h"
#include <Utility/StringExtras.h>
#include <Utility/TemporaryFileStorage.h>
#include <VFS/VFS.h>

namespace nc::panel {

using nc::vfs::easy::CopyDirectoryToTempStorage;
using nc::vfs::easy::CopyFileToTempStorage;

QuickLookVFSBridge::QuickLookVFSBridge(nc::utility::TemporaryFileStorage &_storage, uint64_t _max_size)
    : m_TempStorage(_storage), m_MaxSize(_max_size)
{
}

NSURL *QuickLookVFSBridge::FetchItem(const std::string &_path, VFSHost &_host)
{
    const auto is_dir = _host.IsDirectory(_path, 0);

    if( !is_dir ) {
        const std::expected<VFSStat, Error> st = _host.Stat(_path, 0);
        if( !st )
            return nil;
        if( st->size > m_MaxSize )
            return nil;

        const auto copied_path = CopyFileToTempStorage(_path, _host, m_TempStorage);
        if( !copied_path )
            return nil;

        const auto ns_copied_path = [NSString stringWithUTF8StdString:*copied_path];
        if( !ns_copied_path )
            return nil;

        return [NSURL fileURLWithPath:ns_copied_path];
    }
    else {
        // basic check that directory looks like a bundle
        if( !std::filesystem::path(_path).has_extension() ||
            std::filesystem::path(_path).filename() == std::filesystem::path(_path).extension() )
            return nil;

        const auto copied_path = CopyDirectoryToTempStorage(_path, _host, m_MaxSize, m_TempStorage);
        if( !copied_path )
            return nil;

        const auto ns_copied_path = [NSString stringWithUTF8StdString:*copied_path];
        if( !ns_copied_path )
            return nil;

        return [NSURL fileURLWithPath:ns_copied_path];
    }
}

} // namespace nc::panel

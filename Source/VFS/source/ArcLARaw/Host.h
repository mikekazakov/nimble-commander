// Copyright (C) 2022-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../../include/VFS/Host.h"
#include "../../include/VFS/VFSFile.h"
#include <vector>
#include <string>
#include <cstddef>

namespace nc::vfs {

class ArchiveRawHost final : public Host
{
public:
    static const char *const UniqueTag;

    ArchiveRawHost(std::string_view _path, const VFSHostPtr &_parent, VFSCancelChecker _cancel_checker = {});
    ArchiveRawHost(const VFSHostPtr &_parent, const VFSConfiguration &_config, VFSCancelChecker _cancel_checker = {});

    static VFSMeta Meta();

    std::expected<std::shared_ptr<VFSFile>, Error> CreateFile(std::string_view _path,
                                                              const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<VFSStat, Error>
    Stat(std::string_view _path, unsigned long _flags, const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error>
    IterateDirectoryListing(std::string_view _path,
                            const std::function<bool(const VFSDirEnt &_dirent)> &_handler) override;

    std::expected<VFSListingPtr, Error> FetchDirectoryListing(std::string_view _path,
                                                              unsigned long _flags,
                                                              const VFSCancelChecker &_cancel_checker = {}) override;

    VFSConfiguration Configuration() const override;

    // Tries to extract an original filename from a filename of a compressed file, e.g. "foo.txt"
    // from "foo.txt.bz2". Performs case-insensitive comparisons under the hood. Returns an empty
    // string in case of failure.
    static std::string_view DeduceFilename(std::string_view _path) noexcept;

    // Checks if '_path' has a filename with a supported extension.
    static bool HasSupportedExtension(std::string_view _path) noexcept;

private:
    void Init(const VFSCancelChecker &_cancel_checker);

    std::vector<std::byte> m_Data;
    std::string m_Filename;
    timespec m_MTime;
    VFSConfiguration m_Configuration;
};

} // namespace nc::vfs

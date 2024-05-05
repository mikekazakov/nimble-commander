// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
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

    ArchiveRawHost(const std::string &_path, const VFSHostPtr &_parent, VFSCancelChecker _cancel_checker = {});
    ArchiveRawHost(const VFSHostPtr &_parent, const VFSConfiguration &_config, VFSCancelChecker _cancel_checker = {});

    static VFSMeta Meta();

    int CreateFile(const char *_path,
                   std::shared_ptr<VFSFile> &_target,
                   const VFSCancelChecker &_cancel_checker = {}) override;

    int
    Stat(const char *_path, VFSStat &_st, unsigned long _flags, const VFSCancelChecker &_cancel_checker = {}) override;

    int IterateDirectoryListing(const char *_path,
                                const std::function<bool(const VFSDirEnt &_dirent)> &_handler) override;

    int FetchDirectoryListing(const char *_path,
                              VFSListingPtr &_target,
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

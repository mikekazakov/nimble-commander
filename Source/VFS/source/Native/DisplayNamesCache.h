// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <sys/stat.h>
#include <optional>
#include <unordered_map>
#include <atomic>
#include <Base/spinlock.h>

namespace nc::vfs::native {

/**
 * Presumably should be used only on directories.
 */
class DisplayNamesCache
{
public:
    static DisplayNamesCache &Instance();

    // nullopt string means that there's no dispay string for this
    std::optional<std::string_view> DisplayName(std::string_view _path);
    std::optional<std::string_view> DisplayName(const struct stat &_st, std::string_view _path);
    std::optional<std::string_view> DisplayName(ino_t _ino, dev_t _dev, std::string_view _path);

private:
    std::optional<std::string_view> Fast_Unlocked(ino_t _ino, dev_t _dev, std::string_view _path) const noexcept;
    void Commit_Locked(ino_t _ino, dev_t _dev, std::string_view _path, std::string_view _dispay_name);

    struct Filename {
        std::string_view fs_filename;
        std::string_view display_filename; // empty string means that there's no display name for this item
    };
    using Inodes = std::unordered_multimap<ino_t, Filename>;
    using Devices = std::unordered_map<dev_t, Inodes>;

    std::atomic_int m_Readers{0};
    spinlock m_ReadLock;
    spinlock m_WriteLock;
    Devices m_Devices;
};

} // namespace nc::vfs::native

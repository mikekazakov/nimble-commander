// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <sys/stat.h>
#include <optional>
#include <variant>
#include <atomic>
#include <ankerl/unordered_dense.h>
#include <Base/spinlock.h>

#ifdef __OBJC__
#include <Foundation/Foundation.h>
#endif

namespace nc::vfs::native {

/**
 * Presumably should be used only on directories.
 */
class DisplayNamesCache
{
public:
    struct IO;
    static IO &DefaultIO();

    DisplayNamesCache(IO &_io = DefaultIO());

    static DisplayNamesCache &Instance();

    // nullopt string means that there's no dispay string for this
    std::optional<std::string_view> DisplayName(std::string_view _path);
    std::optional<std::string_view> DisplayName(const struct stat &_st, std::string_view _path);
    std::optional<std::string_view> DisplayName(ino_t _ino, dev_t _dev, std::string_view _path);

private:
    std::optional<std::string_view> Fast_Unlocked(ino_t _ino, dev_t _dev, std::string_view _path) const noexcept;
    const std::string *Slow_Locked(std::string_view _path) const;
    void Commit_Locked(ino_t _ino, dev_t _dev, std::string_view _path, const std::string *_dispay_name);

    struct Filename {
        std::string_view fs_filename;
        const std::string *display_filename = nullptr; // nullptr means that there's no display name for this item
    };
    using InodeFilenames = std::variant<Filename, std::vector<Filename>>;
    using Inodes = ankerl::unordered_dense::map<ino_t, InodeFilenames>;
    using Devices = ankerl::unordered_dense::map<dev_t, Inodes>;

    std::atomic_int m_Readers{0};
    spinlock m_ReadLock;
    spinlock m_WriteLock;
    Devices m_Devices;
    IO &m_IO;
};

#ifdef __OBJC__
// Support for testability with mocks
struct DisplayNamesCache::IO {
    virtual ~IO();
    virtual NSString *DisplayNameAtPath(NSString *_path);
    virtual int Stat(const char *_path, struct stat *_st);
};
#endif

} // namespace nc::vfs::native

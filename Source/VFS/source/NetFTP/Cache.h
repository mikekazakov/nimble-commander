// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <curl/curl.h>
#include <VFS/Host.h>
#include <deque>
#include <mutex>
#include <Base/UnorderedUtil.h>
#include <Base/CFPtr.h>
#include <string_view>
#include <functional>

namespace nc::vfs::ftp {

struct Entry {
    Entry() noexcept = default;
    Entry(const std::string &_name);

    std::string name;
    uint64_t size = 0;
    time_t time = 0;
    mode_t mode = 0;
    mutable bool dirty = false; // true when this entry was explicitly set as outdated

    // links support in the future

    void ToStat(VFSStat &_stat) const;
};

struct Directory {
    std::deque<Entry> entries;
    std::string path; // with trailing slash

    bool dirty_structure = false; // true when there're mismatching between this cache and ftp server
    bool has_dirty_items = false;

    inline bool IsOutdated() const
    {
        return dirty_structure; // || (GetTimeInNanoseconds() > snapshot_time + g_ListingOutdateLimit);
    }

    const Entry *EntryByName(const std::string &_name) const;
};

class Cache
{
public:
    void SetChangesCallback(std::function<void(const std::string &_at_dir)> _handler);

    /**
     * Return nullptr if was not able to find directory.
     */
    std::shared_ptr<Directory> FindDirectory(std::string_view _path) const noexcept;

    /**
     * Commits new freshly downloaded ftp listing.
     * If directory at _path is already in cache - it will be overritten.
     */
    void InsertLISTDirectory(const char *_path, std::shared_ptr<Directory> _dir);

    // incremental and atomic cache update methods:

    /**
     * Will mark entry as dirty and containing directory as has_dirty_items.
     */
    void MakeEntryDirty(const std::string &_path);

    void MarkDirectoryDirty(std::string_view _path);

    /**
     * Creates a new dirty file.
     * If this file already exist in cache - mark it as dirty.
     */
    void CommitNewFile(const std::string &_path);

    /**
     * Erases a dir at _path.
     */
    void CommitRMD(const std::string &_path);

    /**
     * Create a new directory entry.
     */
    void CommitMKD(const std::string &_path);

    /**
     * Erases a entry at _path.
     */
    void CommitUnlink(std::string_view _path);

    /**
     * Removes old entry path and places it as a new entry.
     */
    void CommitRename(const std::string &_old_path, const std::string &_new_path);

private:
    using DirectoriesT = ankerl::unordered_dense::
        map<std::string, std::shared_ptr<Directory>, UnorderedStringHashEqual, UnorderedStringHashEqual>;

    std::shared_ptr<Directory> FindDirectoryInt(std::string_view _path) const noexcept;
    void EraseEntryInt(std::string_view _path);

    DirectoriesT m_Directories; // "/Abra/Cadabra/" -> Directory

    mutable std::mutex m_CacheLock;
    std::function<void(const std::string &_at_dir)> m_Callback;
};

} // namespace nc::vfs::ftp

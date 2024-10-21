// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Cache.h"
#include <VFS/Log.h>
#include <algorithm>
#include <filesystem>

namespace nc::vfs::ftp {

Entry::Entry(const std::string &_name) : name(_name)
{
}

void Entry::ToStat(VFSStat &_stat) const
{
    memset(&_stat, 0, sizeof(_stat));
    _stat.size = size;
    _stat.mode = mode;
    _stat.mtime.tv_sec = time;
    _stat.ctime.tv_sec = time;
    _stat.btime.tv_sec = time;
    _stat.atime.tv_sec = time;

    _stat.meaning.size = 1;
    _stat.meaning.mode = 1;
    _stat.meaning.mtime = _stat.meaning.ctime = _stat.meaning.btime = _stat.meaning.atime = 1;
}

const Entry *Directory::EntryByName(const std::string &_name) const
{
    auto i = std::ranges::find_if(entries, [&](auto &_e) { return _e.name == _name; });
    return i != end(entries) ? &(*i) : nullptr;
}

std::shared_ptr<Directory> Cache::FindDirectory(std::string_view _path) const noexcept
{
    const std::lock_guard<std::mutex> lock(m_CacheLock);

    return FindDirectoryInt(_path);
}

void Cache::MarkDirectoryDirty(std::string_view _path)
{
    assert(!_path.empty() && _path.back() == '/');

    const std::lock_guard<std::mutex> lock(m_CacheLock);
    if( auto d = FindDirectoryInt(_path) )
        d->dirty_structure = true;
}

std::shared_ptr<Directory> Cache::FindDirectoryInt(std::string_view _path) const noexcept
{
    if( _path.empty() || _path.front() != '/' )
        return nullptr;

    assert(_path.back() == '/');

    auto i = m_Directories.find(_path);
    if( i != m_Directories.end() )
        return i->second;

    return nullptr;
}

void Cache::InsertLISTDirectory(const char *_path, std::shared_ptr<Directory> _directory)
{
    Log::Trace("Cache::InsertLISTDirectory({}) called", _path);

    // TODO: also update ->parent_dir here

    if( _path == nullptr || _path[0] != '/' || !_directory )
        return;

    std::string dir = _path;
    if( dir.back() != '/' )
        dir.push_back('/');

    _directory->path = dir;

    const std::lock_guard<std::mutex> lock(m_CacheLock);

    auto i = m_Directories.find(dir);
    if( i != m_Directories.end() )
        i->second = _directory;
    else
        m_Directories.emplace(dir, _directory);
}

void Cache::CommitNewFile(const std::string &_path)
{
    Log::Trace("Cache::CommitNewFile({}) called", _path);

    const std::filesystem::path p = _path;
    assert(p.is_absolute());

    std::filesystem::path dir_path = p.parent_path();
    if( dir_path != "/" )
        dir_path += "/";

    const std::lock_guard<std::mutex> lock(m_CacheLock);
    auto dir = FindDirectoryInt(dir_path.native());
    if( dir != nullptr ) {
        if( auto entry = dir->EntryByName(p.filename().native()) ) {
            entry->dirty = true;
            dir->has_dirty_items = true;
            return;
        }

        auto copy = std::make_shared<Directory>(*dir);
        copy->entries.emplace_back(p.filename().native());
        copy->entries.back().mode = S_IFREG;
        copy->entries.back().dirty = true;
        copy->has_dirty_items = true;

        m_Directories.find(dir_path.native())->second = copy;
        m_Callback(dir_path.native());
    }
}

void Cache::MakeEntryDirty(const std::string &_path)
{
    Log::Trace("Cache::MakeEntryDirty({}) called", _path);
    const std::filesystem::path p = _path;
    assert(p.is_absolute());

    std::filesystem::path dir_path = p.parent_path();
    if( dir_path != "/" )
        dir_path += "/";

    const std::lock_guard<std::mutex> lock(m_CacheLock);
    auto dir = FindDirectoryInt(dir_path.native());
    if( dir ) {
        auto entry = dir->EntryByName(p.filename().native());
        if( entry ) {
            entry->dirty = true;
            dir->has_dirty_items = true;
        }
    }
}

void Cache::CommitRMD(const std::string &_path)
{
    Log::Trace("Cache::CommitRMD({}) called", _path);
    const std::lock_guard<std::mutex> lock(m_CacheLock);

    EraseEntryInt(_path);

    std::filesystem::path p = _path;
    p += "/";

    auto i = m_Directories.find(p.native());
    if( i != m_Directories.end() )
        m_Directories.erase(i);
}

void Cache::CommitUnlink(std::string_view _path)
{
    Log::Trace("Cache::CommitUnlink({}) called", _path);
    const std::lock_guard<std::mutex> lock(m_CacheLock);
    EraseEntryInt(_path);
}

void Cache::CommitMKD(const std::string &_path)
{
    Log::Trace("Cache::CommitMKD({}) called", _path);
    const std::filesystem::path p = _path;
    assert(p.is_absolute());

    std::filesystem::path dir_path = p.parent_path();
    if( dir_path != "/" )
        dir_path += "/";

    const std::lock_guard<std::mutex> lock(m_CacheLock);
    auto dir = FindDirectoryInt(dir_path.native());
    if( dir != nullptr ) {
        auto copy = std::make_shared<Directory>(*dir);
        copy->entries.emplace_back(p.filename().native());
        copy->entries.back().mode = S_IFDIR;
        copy->entries.back().dirty = true;
        copy->has_dirty_items = true;

        m_Directories.find(dir_path.native())->second = copy;
    }
    m_Callback(dir_path.native());
}

void Cache::CommitRename(const std::string &_old_path, const std::string &_new_path)
{
    Log::Trace("Cache::CommitRename({}, {}) called", _old_path, _new_path);
    std::filesystem::path old_path = _old_path;
    std::filesystem::path new_path = _new_path;
    assert(old_path.is_absolute() && new_path.is_absolute());

    const std::lock_guard<std::mutex> lock(m_CacheLock);

    std::filesystem::path old_par_path = old_path.parent_path();
    if( old_par_path != "/" )
        old_par_path += "/";
    std::filesystem::path new_par_path = new_path.parent_path();
    if( new_par_path != "/" )
        new_par_path += "/";

    const bool same_dir = old_path.parent_path() == new_path.parent_path();

    const Entry *old_entry = nullptr;
    auto dir = FindDirectoryInt(old_par_path.native());
    if( dir ) {
        auto copy = std::make_shared<Directory>();
        copy->path = dir->path;
        copy->dirty_structure = dir->dirty_structure;
        copy->has_dirty_items = dir->has_dirty_items;

        for( auto &i : dir->entries )
            if( i.name != old_path.filename() ) {
                copy->entries.emplace_back(i);
            }
            else if( same_dir ) {
                Entry e(new_path.filename().native());
                e.size = i.size;
                e.time = i.time;
                e.mode = i.mode;
                e.dirty = i.dirty;
                copy->entries.push_back(e);
            }
            else
                old_entry = &i;

        m_Directories.find(old_par_path.native())->second = copy;
    }

    if( !same_dir && old_entry ) {
        dir = FindDirectoryInt(new_par_path.native());
        if( dir ) {
            auto copy = std::make_shared<Directory>(*dir);

            Entry e(new_path.filename().native());
            e.size = old_entry->size;
            e.time = old_entry->time;
            e.mode = old_entry->mode;
            e.dirty = old_entry->dirty;
            copy->entries.push_back(e);

            m_Directories.find(new_par_path.native())->second = copy;
        }
    }

    // if _old_path was a dir and we have it in cache - need to rename it too
    if( old_path != "/" )
        old_path /= "/";
    if( new_path != "/" )
        new_path /= "/";
    auto self_dir = m_Directories.find(old_path.c_str());
    if( self_dir != m_Directories.end() ) {
        auto data = self_dir->second;
        m_Directories.erase(self_dir);
        m_Directories.emplace(new_path.native(), data);
    }
}

void Cache::EraseEntryInt(std::string_view _path)
{
    Log::Trace("Cache::EraseEntryInt({}) called", _path);
    const std::filesystem::path p = _path;
    assert(p.filename() != ""); // _path with no trailing slashes
    assert(p.is_absolute());

    // find and erase entry of this dir in parent dir if any
    std::filesystem::path dir_path = p.parent_path();
    if( dir_path != "/" )
        dir_path += "/";

    auto dir = FindDirectoryInt(dir_path.native());
    if( dir ) {
        auto copy = std::make_shared<Directory>();
        copy->path = dir->path;
        copy->dirty_structure = dir->dirty_structure;
        copy->has_dirty_items = dir->has_dirty_items;

        for( auto &i : dir->entries )
            if( i.name != p.filename() )
                copy->entries.emplace_back(i);
        m_Directories.find(dir_path.native())->second = copy;
    }
    m_Callback(dir_path.native());
}

void Cache::SetChangesCallback(std::function<void(const std::string &_at_dir)> _handler)
{
    m_Callback = std::move(_handler);
}

} // namespace nc::vfs::ftp

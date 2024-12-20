// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DisplayNamesCache.h"
#include <Foundation/Foundation.h>
#include <Utility/StringExtras.h>
#include <Utility/PathManip.h>
#include <ankerl/unordered_dense.h>
#include <Base/UnorderedUtil.h>
#include <VFS/Log.h>
#include <ranges>
#include <algorithm>

namespace nc::vfs::native {

static const std::string *Internalize(std::string_view _string) noexcept
{
    [[clang::no_destroy]] static constinit std::mutex mtx;
    [[clang::no_destroy]] static ankerl::unordered_dense::
        segmented_set<std::string, UnorderedStringHashEqual, UnorderedStringHashEqual> strings;

    assert(!_string.empty());

    const std::lock_guard lock{mtx};
    if( auto it = strings.find(_string); it != strings.end() ) {
        return &*it;
    }
    else {
        return &*strings.emplace(_string).first;
    }
}

DisplayNamesCache::DisplayNamesCache(IO &_io) : m_IO(_io)
{
    static_assert(sizeof(Filename) == 24);
    static_assert(sizeof(InodeFilenames) == 32); // 24b + 8b of variant discriminator
}

DisplayNamesCache &DisplayNamesCache::Instance()
{
    [[clang::no_destroy]] static DisplayNamesCache inst;
    return inst;
}

std::optional<std::string_view>
DisplayNamesCache::Fast_Unlocked(ino_t _ino, dev_t _dev, std::string_view _path) const noexcept
{
    // O(1)
    const auto inodes = m_Devices.find(_dev);
    if( inodes == m_Devices.end() )
        return std::nullopt;

    // O(1)
    const auto filenames = inodes->second.find(_ino);
    if( filenames == inodes->second.end() )
        return std::nullopt;

    // O(N), N = amount of times the same inode was used and encountered with a different filename, normally N ~= 1
    const std::string_view filename = utility::PathManip::Filename(_path);
    if( const Filename *f = std::get_if<Filename>(&filenames->second) ) {
        // There is only one entry for this inode
        if( f->fs_filename == filename ) {
            return f->display_filename ? std::string_view{*f->display_filename} : std::string_view{};
        }
    }
    else if( const std::vector<Filename> *ff = std::get_if<std::vector<Filename>>(&filenames->second) ) {
        // There are multiple entries for this inode, need to check the one by one
        const auto found = std::ranges::find_if(*ff, [&](const Filename &f) { return f.fs_filename == filename; });
        if( found != ff->end() )
            return found->display_filename ? std::string_view{*found->display_filename} : std::string_view{};
    }
    return std::nullopt;
}

void DisplayNamesCache::Commit_Locked(ino_t _ino, dev_t _dev, std::string_view _path, const std::string *_dispay_name)
{
    // Prepare the entry to insert into the cache
    Filename f;
    f.fs_filename = *Internalize(utility::PathManip::Filename(_path));
    f.display_filename = _dispay_name;

    const std::lock_guard<spinlock> guard(m_WriteLock);

    // O(1) - find or create a per-device inode map
    Inodes &inodes = m_Devices[_dev];

    // O(1) - find an entry for this inode
    if( auto it = inodes.find(_ino); it != inodes.end() ) {
        if( const Filename *existing_filename = std::get_if<Filename>(&it->second) ) {
            // There is one entry there already, we need to convert it to a vector with two elements
            std::vector<Filename> vec{*existing_filename, f};
            it->second = std::move(vec);
        }
        else {
            // This inode was already encountered with a different filename, add a new entry to the vector
            std::vector<Filename> &filenames = std::get<std::vector<Filename>>(it->second);
            filenames.push_back(f);
        }
    }
    else {
        // Not there, therefore insert as a single entry
        inodes.emplace(_ino, f);
    }

    Log::Trace("DisplayNamesCache::Commit_Locked: cached `{}` / inode={} / dev={} -> `{}`",
               _path,
               _ino,
               _dev,
               _dispay_name ? _dispay_name->c_str() : "");
    Log::Trace("DisplayNamesCache::Commit_Locked: total amount of cached entries on dev={}: {}", _dev, inodes.size());
}

std::optional<std::string_view> DisplayNamesCache::DisplayName(const struct stat &_st, std::string_view _path)
{
    return DisplayName(_st.st_ino, _st.st_dev, _path);
}

std::optional<std::string_view> DisplayNamesCache::DisplayName(std::string_view _path)
{
    std::array<char, 512> mem_buffer;
    std::pmr::monotonic_buffer_resource mem_resource(mem_buffer.data(), mem_buffer.size());
    const std::pmr::string path(_path, &mem_resource);

    struct stat st;
    if( m_IO.Stat(path.c_str(), &st) != 0 )
        return std::nullopt;
    return DisplayName(st, _path);
}

const std::string *DisplayNamesCache::Slow_Locked(std::string_view _path) const
{
    Log::Trace("DisplayNamesCache::Slow_Locked: looking up a display filename for `{}`", _path);
    NSString *const path = [NSString stringWithUTF8StdStringView:_path];
    if( path == nil )
        return nullptr; // can't create string for this path.

    NSString *display_name = m_IO.DisplayNameAtPath(path);
    if( display_name == nil )
        return nullptr; // something strange has happen

    display_name = [display_name decomposedStringWithCanonicalMapping];
    assert(display_name.UTF8String != nullptr);
    const std::string_view display_utf8_name = display_name.UTF8String;

    if( display_utf8_name.empty() )
        return nullptr; // ignore empty display names

    if( _path == display_utf8_name )
        return nullptr; // this means error: "If there is no file or directory at path, or if an error occurs, returns
                        // path as is."

    if( utility::PathManip::Filename(_path) == display_utf8_name )
        return nullptr; // this display name is exactly like the filesystem one

    return Internalize(display_utf8_name);
}

std::optional<std::string_view> DisplayNamesCache::DisplayName(ino_t _ino, dev_t _dev, std::string_view _path)
{
    // many readers, one writer | readers preference, based on atomic spinlocks

    // FAST PATH BEGINS
    m_ReadLock.lock();
    if( (++m_Readers) == 1 )
        m_WriteLock.lock();
    m_ReadLock.unlock();

    const auto existed = Fast_Unlocked(_ino, _dev, _path);

    m_ReadLock.lock();
    if( (--m_Readers) == 0 )
        m_WriteLock.unlock();
    m_ReadLock.unlock();

    if( existed ) {
        if( existed->empty() ) {
            return std::nullopt;
        }
        else {
            return existed;
        }
    }
    // FAST PATH ENDS

    // SLOW PATH BEGINS
    const std::string *internalized_str = Slow_Locked(_path);
    Commit_Locked(_ino, _dev, _path, internalized_str);
    if( internalized_str ) {
        assert(!internalized_str->empty());
        return *internalized_str;
    }
    else {
        return std::nullopt;
    }
    // SLOW PATH ENDS
}

DisplayNamesCache::IO &DisplayNamesCache::DefaultIO()
{
    [[clang::no_destroy]] static IO io;
    return io;
}

DisplayNamesCache::IO::~IO() = default;

NSString *DisplayNamesCache::IO::DisplayNameAtPath(NSString *_path)
{
    static NSFileManager *const filemanager = NSFileManager.defaultManager;
    return [filemanager displayNameAtPath:_path];
}

int DisplayNamesCache::IO::Stat(const char *_path, struct stat *_st)
{
    return stat(_path, _st);
}

} // namespace nc::vfs::native

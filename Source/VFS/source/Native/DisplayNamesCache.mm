// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DisplayNamesCache.h"
#include <Foundation/Foundation.h>
#include <Utility/StringExtras.h>
#include <Utility/PathManip.h>
#include <ankerl/unordered_dense.h>
#include <Base/UnorderedUtil.h>

namespace nc::vfs::native {

static std::string_view Internalize(std::string_view _string) noexcept
{
    [[clang::no_destroy]] static constinit std::mutex mtx;
    [[clang::no_destroy]] static ankerl::unordered_dense::
        segmented_set<std::string, UnorderedStringHashEqual, UnorderedStringHashEqual> strings;

    std::lock_guard lock{mtx};
    if( auto it = strings.find(_string); it != strings.end() ) {
        return *it;
    }
    else {
        return *strings.emplace(_string).first;
    }
}

DisplayNamesCache &DisplayNamesCache::Instance()
{
    [[clang::no_destroy]] static DisplayNamesCache inst;
    return inst;
}

std::optional<std::string_view>
DisplayNamesCache::Fast_Unlocked(ino_t _ino, dev_t _dev, std::string_view _path) const noexcept
{
    const auto inodes = m_Devices.find(_dev);
    if( inodes == m_Devices.end() )
        return std::nullopt;

    const std::string_view filename = utility::PathManip::Filename(_path);

    const auto range = inodes->second.equal_range(_ino);
    for( auto i = range.first; i != range.second; ++i )
        if( i->second.fs_filename == filename )
            return i->second.display_filename;

    return std::nullopt;
}

void DisplayNamesCache::Commit_Locked(ino_t _ino, dev_t _dev, std::string_view _path, std::string_view _dispay_name)
{
    Filename f;
    f.fs_filename = Internalize(utility::PathManip::Filename(_path));
    f.display_filename = _dispay_name;
    const std::lock_guard<spinlock> guard(m_WriteLock);
    m_Devices[_dev].insert(std::make_pair(_ino, f));
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
    if( stat(path.c_str(), &st) != 0 )
        return std::nullopt;
    return DisplayName(st, _path);
}

static NSFileManager *filemanager = NSFileManager.defaultManager;
static std::string_view Slow(std::string_view _path)
{
    NSString *const path = [NSString stringWithUTF8StdStringView:_path];
    if( path == nil )
        return {}; // can't create string for this path.

    NSString *display_name = [filemanager displayNameAtPath:path];
    if( display_name == nil )
        return {}; // something strange has happen

    display_name = [display_name decomposedStringWithCanonicalMapping];
    assert(display_name.UTF8String != nullptr);
    const std::string_view display_utf8_name = display_name.UTF8String;

    if( display_utf8_name.empty() )
        return {}; // ignore empty display names

    if( utility::PathManip::Filename(_path) == display_utf8_name )
        return {}; // this display name is exactly like the filesystem one

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
            return *existed;
        }
    }
    // FAST PATH ENDS

    // SLOW PATH BEGINS
    const std::string_view internalized_str = Slow(_path);
    Commit_Locked(_ino, _dev, _path, internalized_str);
    if( internalized_str.empty() ) {
        return std::nullopt;
    }
    else {
        return internalized_str;
    }
    // SLOW PATH ENDS
}

} // namespace nc::vfs::native

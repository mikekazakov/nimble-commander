// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "NativeFSHelpers.h"
#include <sys/stat.h>
#include <sys/param.h>
#include <sys/mount.h>

namespace nc::ops::copying {

bool ShouldPreallocateSpace(uint64_t _bytes_to_write, const utility::NativeFileSystemInfo &_fs_info) noexcept
{
    // Only bother with preallocation when the amount of data we're going to write it large that the optimal I/O size.
    // Otherwise, it will be a single write call anyway.
    const uint32_t min_prealloc_size = _fs_info.basic.io_size;
    if( _bytes_to_write <= min_prealloc_size )
        return false;

    // Need to check destination fs and permit preallocation only on certain filesystems
    constexpr std::string_view hfs_plus = "hfs";
    constexpr std::string_view apfs = "apfs";
    return _fs_info.fs_type_name == hfs_plus || //
           _fs_info.fs_type_name == apfs;
}

// PreallocateSpace assumes following ftruncate, meaningless otherwise (??)
bool TryToPreallocateSpace(uint64_t _preallocate_delta, int _file_des) noexcept
{
    // at first try to request a single contiguous block
    fstore_t preallocstore = {F_ALLOCATECONTIG, F_PEOFPOSMODE, 0, static_cast<off_t>(_preallocate_delta), 0};
    if( fcntl(_file_des, F_PREALLOCATE, &preallocstore) == 0 )
        return true;

    // now try to preallocate the space in some chunks
    preallocstore.fst_flags = F_ALLOCATEALL;
    return fcntl(_file_des, F_PREALLOCATE, &preallocstore) == 0;
}

bool SupportsFastTruncationAfterPreallocation(const utility::NativeFileSystemInfo &_fs_info) noexcept
{
    constexpr std::string_view hfs_plus = "hfs";
    constexpr std::string_view apfs = "apfs";
    return _fs_info.fs_type_name == hfs_plus || //
           _fs_info.fs_type_name == apfs;
}

void AdjustFileTimesForNativePath(const char *_target_path, struct stat &_with_times)
{
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    attrs.commonattr = ATTR_CMN_CRTIME | ATTR_CMN_MODTIME | ATTR_CMN_CHGTIME | ATTR_CMN_ACCTIME;
    struct timespec values[4] = {
        _with_times.st_birthtimespec, _with_times.st_mtimespec, _with_times.st_ctimespec, _with_times.st_atimespec};
    setattrlist(_target_path, &attrs, &values[0], sizeof(values), 0);
}

void AdjustFileTimesForNativePath(const char *_target_path, const VFSStat &_with_times)
{
    auto st = _with_times.SysStat();
    AdjustFileTimesForNativePath(_target_path, st);
}

void AdjustFileTimesForNativeFD(int _target_fd, struct stat &_with_times)
{
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    attrs.commonattr = ATTR_CMN_CRTIME | ATTR_CMN_MODTIME | ATTR_CMN_CHGTIME | ATTR_CMN_ACCTIME;
    struct timespec values[4] = {
        _with_times.st_birthtimespec, _with_times.st_mtimespec, _with_times.st_ctimespec, _with_times.st_atimespec};
    fsetattrlist(_target_fd, &attrs, &values[0], sizeof(values), 0);
}

void AdjustFileTimesForNativeFD(int _target_fd, const VFSStat &_with_times)
{
    auto st = _with_times.SysStat();
    AdjustFileTimesForNativeFD(_target_fd, st);
}

bool IsAnExternalExtenedAttributesStorage(VFSHost &_host,
                                          const std::string &_path,
                                          const std::string &_item_name,
                                          const VFSStat &_st,
                                          nc::utility::NativeFSManager *_native_fs_man)
{
    // currently we think that ExtEAs can be only on native VFS
    if( !_host.IsNativeFS() )
        return false;

    // any ExtEA should have ._Filename format
    auto cstring = _item_name.c_str();
    if( cstring[0] != '.' || cstring[1] != '_' || cstring[2] == 0 )
        return false;

    if( !_st.mode_bits.reg )
        return false;

    // check if current filesystem uses external eas
    assert(_native_fs_man);
    auto fs_info = _native_fs_man->VolumeFromPath(_path);
    if( !fs_info || fs_info->interfaces.extended_attr )
        return false;

    // check if a 'main' file exists
    char path[MAXPATHLEN];
    strcpy(path, _path.c_str());

    // some magick to produce /path/subpath/filename from a /path/subpath/._filename
    char *last_dst = strrchr(path, '/');
    if( !last_dst )
        return false;
    strcpy(last_dst + 1, cstring + 2);

    return _host.Exists(path);
}

} // namespace nc::ops::copying

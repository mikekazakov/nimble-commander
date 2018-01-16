// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "NativeFSHelpers.h"

namespace nc::ops::copying {

bool ShouldPreallocateSpace(int64_t _bytes_to_write, const NativeFileSystemInfo &_fs_info) noexcept
{
    const auto min_prealloc_size = 4096;
    if( _bytes_to_write <= min_prealloc_size )
        return false;

    // Need to check destination fs and permit preallocation only on certain filesystems
    static const auto prealloc_on = { "hfs"s, "apfs"s };
    return count( begin(prealloc_on), end(prealloc_on), _fs_info.fs_type_name ) != 0;
}

// PreallocateSpace assumes following ftruncate, meaningless otherwise on HFS+ (??)
bool TryToPreallocateSpace(int64_t _preallocate_delta, int _file_des) noexcept
{
    // at first try to request a single contiguous block
    fstore_t preallocstore = {F_ALLOCATECONTIG, F_PEOFPOSMODE, 0, _preallocate_delta};
    if( fcntl(_file_des, F_PREALLOCATE, &preallocstore) == 0 )
        return true;
    
    // now try to preallocate the space in some chunks
    preallocstore.fst_flags = F_ALLOCATEALL;
    if( fcntl(_file_des, F_PREALLOCATE, &preallocstore) == 0 )
        return true;
    
    return false;
}
    
bool SupportsFastTruncationAfterPreallocation(const NativeFileSystemInfo &_fs_info) noexcept
{
    // For some reasons, as of 10.13.2, "apfs" behaves strangely and writes the entire preallocated
    // space (presumably zeroing the space) upon ftruncate() call, which causes a significant and
    // noticable lag. Thus, until something changes in F_PREALLOCATE/ftruncate() implementation on
    // APFS or some clarification on the situation appears, the preallocation is not followed with
    // ftruncate() for this FS.
    
    static const auto hfs_plus = "hfs"s;
    return _fs_info.fs_type_name == hfs_plus;
}

void AdjustFileTimesForNativePath(const char* _target_path, struct stat &_with_times)
{
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    attrs.commonattr = ATTR_CMN_CRTIME | ATTR_CMN_MODTIME | ATTR_CMN_CHGTIME | ATTR_CMN_ACCTIME;
    struct timespec values[4] = {   _with_times.st_birthtimespec,
                                    _with_times.st_mtimespec,
                                    _with_times.st_ctimespec,
                                    _with_times.st_atimespec    };
    setattrlist(_target_path,
                 &attrs,
                 &values[0],
                 sizeof(values),
                 0);

}

void AdjustFileTimesForNativePath(const char* _target_path, const VFSStat &_with_times)
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
    struct timespec values[4] = {   _with_times.st_birthtimespec,
                                    _with_times.st_mtimespec,
                                    _with_times.st_ctimespec,
                                    _with_times.st_atimespec    };
    fsetattrlist(_target_fd,
                 &attrs,
                 &values[0],
                 sizeof(values),
                 0);
}

void AdjustFileTimesForNativeFD(int _target_fd, const VFSStat &_with_times)
{
    auto st = _with_times.SysStat();
    AdjustFileTimesForNativeFD(_target_fd, st);
}

bool IsAnExternalExtenedAttributesStorage(VFSHost &_host,
                                          const string &_path,
                                          const string& _item_name,
                                          const VFSStat &_st )
{
    // currently we think that ExtEAs can be only on native VFS
    if( !_host.IsNativeFS() )
        return false;
    
    // any ExtEA should have ._Filename format
    auto cstring = _item_name.c_str();
    if( cstring[0] != '.' || cstring[1] != '_' || cstring[2] == 0 )
        return false;
    
    // check if current filesystem uses external eas
    auto fs_info = NativeFSManager::Instance().VolumeFromDevID( _st.dev );
    if( !fs_info || fs_info->interfaces.extended_attr == true )
        return false;
    
    // check if a 'main' file exists
    char path[MAXPATHLEN];
    strcpy(path, _path.c_str());
    
    // some magick to produce /path/subpath/filename from a /path/subpath/._filename
    char *last_dst = strrchr(path, '/');
    if( !last_dst )
        return false;
    strcpy( last_dst + 1, cstring + 2 );
    
    return _host.Exists( path );
}
    
}

// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "NativeFSHelpers.h"

namespace nc::ops::copying {

bool ShouldPreallocateSpace(int64_t _bytes_to_write, const NativeFileSystemInfo &_fs_info)
{
    const auto min_prealloc_size = 4096;
    if( _bytes_to_write <= min_prealloc_size )
        return false;

    // need to check destination fs and permit preallocation only on certain filesystems
    static const auto prealloc_on = { "hfs"s, "apfs"s };
    return count( begin(prealloc_on), end(prealloc_on), _fs_info.fs_type_name ) != 0;
}

// PreallocateSpace assumes following ftruncate, meaningless otherwise
void PreallocateSpace(int64_t _preallocate_delta, int _file_des)
{
    fstore_t preallocstore = {F_ALLOCATECONTIG, F_PEOFPOSMODE, 0, _preallocate_delta};
    if( fcntl(_file_des, F_PREALLOCATE, &preallocstore) == -1 ) {
        preallocstore.fst_flags = F_ALLOCATEALL;
        fcntl(_file_des, F_PREALLOCATE, &preallocstore);
    }
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


}

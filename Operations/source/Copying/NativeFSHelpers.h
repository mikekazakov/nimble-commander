#pragma once

#include <Utility/NativeFSManager.h>
#include <VFS/VFS.h>

namespace nc::ops::copying {

bool ShouldPreallocateSpace(int64_t _bytes_to_write, const NativeFileSystemInfo &_fs_info);
void PreallocateSpace(int64_t _preallocate_delta, int _file_des);
void AdjustFileTimesForNativePath(const char* _target_path, struct stat &_with_times);
void AdjustFileTimesForNativePath(const char* _target_path, const VFSStat &_with_times);
void AdjustFileTimesForNativeFD(int _target_fd, struct stat &_with_times);
void AdjustFileTimesForNativeFD(int _target_fd, const VFSStat &_with_times);

};

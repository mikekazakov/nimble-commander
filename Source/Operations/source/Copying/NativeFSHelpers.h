// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/NativeFSManager.h>
#include <VFS/VFS.h>

namespace nc::ops::copying {

bool ShouldPreallocateSpace(int64_t _bytes_to_write, const utility::NativeFileSystemInfo &_fs_info) noexcept;
bool TryToPreallocateSpace(int64_t _preallocate_delta, int _file_des) noexcept;
bool SupportsFastTruncationAfterPreallocation(const utility::NativeFileSystemInfo &_fs_info) noexcept;

void AdjustFileTimesForNativePath(const char *_target_path, struct stat &_with_times);
void AdjustFileTimesForNativePath(const char *_target_path, const VFSStat &_with_times);
void AdjustFileTimesForNativeFD(int _target_fd, struct stat &_with_times);
void AdjustFileTimesForNativeFD(int _target_fd, const VFSStat &_with_times);

bool IsAnExternalExtenedAttributesStorage(VFSHost &_host,
                                          const std::string &_path,
                                          const std::string &_item_name,
                                          const VFSStat &_st,
                                          nc::utility::NativeFSManager *_native_fs_man);

}; // namespace nc::ops::copying

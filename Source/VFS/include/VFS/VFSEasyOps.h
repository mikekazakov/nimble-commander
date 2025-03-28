// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include "VFSFile.h"
#include "Host.h"
#include <optional>
#include <filesystem>

namespace nc::utility {
class TemporaryFileStorage;
};

std::expected<void, nc::Error> VFSEasyCopyFile(const char *_src_full_path,
                                               std::shared_ptr<VFSHost> _src_host,
                                               const char *_dst_full_path,
                                               std::shared_ptr<VFSHost> _dst_host);

std::expected<int, nc::Error> VFSEasyCompareFiles(const char *_file1_full_path,
                                                  std::shared_ptr<VFSHost> _file1_host,
                                                  const char *_file2_full_path,
                                                  std::shared_ptr<VFSHost> _file2_host);

/**
 * Will delete an entry at _full_path.
 * If entry is a dir, will recursively delete it's content.
 */
std::expected<void, nc::Error> VFSEasyDelete(const char *_full_path, const std::shared_ptr<VFSHost> &host);

/**
 * _dst_full_path - is a directory to where source directory should be copied. Top-level directory will be created,
 * an function will fail on such existing directory in destination.
 * Example params: source: /foo/bar1/my_dir, dest: /foo/bar2/my_dir
 *
 */
std::expected<void, nc::Error> VFSEasyCopyDirectory(const char *_src_full_path,
                                                    std::shared_ptr<VFSHost> _src_host,
                                                    const char *_dst_full_path,
                                                    std::shared_ptr<VFSHost> _dst_host);

std::expected<void, nc::Error> VFSEasyCopySymlink(const char *_src_full_path,
                                                  std::shared_ptr<VFSHost> _src_host,
                                                  const char *_dst_full_path,
                                                  std::shared_ptr<VFSHost> _dst_host);

std::expected<void, nc::Error> VFSEasyCopyNode(const char *_src_full_path,
                                               std::shared_ptr<VFSHost> _src_host,
                                               const char *_dst_full_path,
                                               std::shared_ptr<VFSHost> _dst_host);

std::expected<void, nc::Error> VFSEasyCreateEmptyFile(std::string_view _path, const VFSHostPtr &_vfs);

std::expected<int, nc::Error> VFSCompareNodes(const std::filesystem::path &_file1_full_path,
                                              const VFSHostPtr &_file1_host,
                                              const std::filesystem::path &_file2_full_path,
                                              const VFSHostPtr &_file2_host);

namespace nc::vfs::easy {

std::optional<std::string> CopyFileToTempStorage(const std::string &_vfs_filepath,
                                                 VFSHost &_host,
                                                 nc::utility::TemporaryFileStorage &_temp_storage,
                                                 const std::function<bool()> &_cancel_checker = {});

std::optional<std::string> CopyDirectoryToTempStorage(const std::string &_vfs_dirpath,
                                                      VFSHost &_host,
                                                      uint64_t _max_total_size,
                                                      nc::utility::TemporaryFileStorage &_temp_storage,
                                                      const std::function<bool()> &_cancel_checker = {});

} // namespace nc::vfs::easy

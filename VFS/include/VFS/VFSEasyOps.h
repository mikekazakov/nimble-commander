// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <boost/filesystem.hpp>
#import "VFSFile.h"
#import "Host.h"


int VFSEasyCopyFile(const char *_src_full_path,
                    std::shared_ptr<VFSHost> _src_host,
                    const char *_dst_full_path,
                    std::shared_ptr<VFSHost> _dst_host
                    );


int VFSEasyCompareFiles(const char *_file1_full_path,
                        std::shared_ptr<VFSHost> _file1_host,
                        const char *_file2_full_path,
                        std::shared_ptr<VFSHost> _file2_host,
                        int &_result
                        );

/**
 * Will delete an entry at _full_path.
 * If entry is a dir, will recursively delete it's content.
 */
int VFSEasyDelete(const char *_full_path, const std::shared_ptr<VFSHost> &host);

/**
 * _dst_full_path - is a directory to where source directory should be copied. Top-level directory will be created,
 * an function will fail on such existing directory in destination.
 * Example params: source: /foo/bar1/my_dir, dest: /foo/bar2/my_dir
 *
 */
int VFSEasyCopyDirectory(const char *_src_full_path,
                         std::shared_ptr<VFSHost> _src_host,
                         const char *_dst_full_path,
                         std::shared_ptr<VFSHost> _dst_host
                         );

int VFSEasyCopySymlink(const char *_src_full_path,
                       std::shared_ptr<VFSHost> _src_host,
                       const char *_dst_full_path,
                       std::shared_ptr<VFSHost> _dst_host
                       );

int VFSEasyCopyNode(const char *_src_full_path,
                    std::shared_ptr<VFSHost> _src_host,
                    const char *_dst_full_path,
                    std::shared_ptr<VFSHost> _dst_host
                    );

int VFSEasyCreateEmptyFile(const char *_path, const VFSHostPtr &_vfs);

int VFSCompareNodes(const boost::filesystem::path& _file1_full_path,
                    const VFSHostPtr& _file1_host,
                    const boost::filesystem::path& _file2_full_path,
                    const VFSHostPtr& _file2_host,
                    int &_result);

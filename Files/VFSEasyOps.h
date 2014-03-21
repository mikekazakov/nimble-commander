//
//  VFSEasyOps.h
//  Files
//
//  Created by Michael G. Kazakov on 27.01.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import "VFSFile.h"
#import "VFSHost.h"

int VFSEasyCopyFile(const char *_src_full_path,
                    shared_ptr<VFSHost> _src_host,
                    const char *_dst_full_path,
                    shared_ptr<VFSHost> _dst_host
                    );


int VFSEasyCompareFiles(const char *_file1_full_path,
                        shared_ptr<VFSHost> _file1_host,
                        const char *_file2_full_path,
                        shared_ptr<VFSHost> _file2_host,
                        int &_result
                        );

/**
 * _dst_full_path - is a directory to where source directory should be copied. Top-level directory will be created,
 * an function will fail on such existing directory in destination.
 * Example params: source: /foo/bar1/my_dir, dest: /foo/bar2/my_dir
 *
 */
int VFSEasyCopyDirectory(const char *_src_full_path,
                         shared_ptr<VFSHost> _src_host,
                         const char *_dst_full_path,
                         shared_ptr<VFSHost> _dst_host
                         );

int VFSEasyCopySymlink(const char *_src_full_path,
                       shared_ptr<VFSHost> _src_host,
                       const char *_dst_full_path,
                       shared_ptr<VFSHost> _dst_host
                       );

int VFSEasyCopyNode(const char *_src_full_path,
                    shared_ptr<VFSHost> _src_host,
                    const char *_dst_full_path,
                    shared_ptr<VFSHost> _dst_host
                    );


//
//  TemporaryNativeFilesStorage.h
//  Files
//
//  Created by Michael G. Kazakov on 03.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "vfs/VFS.h"

// this class allows to grab a non-native VFS file, put is into temporary native dir and do something later
// does not change original filename, using many directories to avoid collisions
class TemporaryNativeFileStorage
{
public:
    bool CopySingleFile(const string &_vfs_filepath,
                        const VFSHostPtr &_host,
                        string& _tmp_filepath
                        ); // can run from any thread

    // _vfs_dirpath may be with trailing slash or without
    bool CopyDirectory(const string &_vfs_dirpath,
                       const VFSHostPtr &_host,
                       uint64_t _max_total_size,
                       function<bool()> _cancel_checker,
                       string &_tmp_dirpath);
                       
    static TemporaryNativeFileStorage &Instance();
private:
    TemporaryNativeFileStorage();
    ~TemporaryNativeFileStorage();
    
    TemporaryNativeFileStorage(const TemporaryNativeFileStorage&) = delete;
    void operator =(const TemporaryNativeFileStorage&) = delete;
  
    string NewTempDir(); // can run from any thread
    bool GetSubDirForFilename(const char *_filename, char *_full_path); // can run from any thread
    
    mutex           m_SubDirsLock;
    vector<string>  m_SubDirs; // modifications should be guarded with m_ControlQueue
};

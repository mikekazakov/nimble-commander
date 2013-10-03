//
//  TemporaryNativeFilesStorage.h
//  Files
//
//  Created by Michael G. Kazakov on 03.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "VFS.h"
#import <list>
#import <vector>


// this class allows to grab a non-native VFS file, put is into temporary native dir and do something later
// does not change original filename, using many directories to avoid collisions
class TemporaryNativeFileStorage
{
public:
    bool CopySingleFile(const char* _vfs_filename,
                        std::shared_ptr<VFSHost> _host,
                        char *_tmp_filename
                        ); // can run from any thread

    static void StartBackgroundPurging(); // should be called once upon application start
    
    static TemporaryNativeFileStorage &Instance();
private:
    TemporaryNativeFileStorage();
    ~TemporaryNativeFileStorage();
    
    TemporaryNativeFileStorage(const TemporaryNativeFileStorage&) = delete;
    void operator =(const TemporaryNativeFileStorage&) = delete;
  
    bool NewTempDir(char *_full_path); // can run from any thread
    bool GetSubDirForFilename(const char *_filename, char *_full_path); // can run from any thread
    
    dispatch_queue_t        m_ControlQueue;
    char                    m_TmpDirPath[MAXPATHLEN];
    std::list<std::string>  m_SubDirs; // modifications should be guarded with m_ControlQueue
};

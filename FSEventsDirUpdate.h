//
//  FSEventsDirUpdate.h
//  Directories
//
//  Created by Michael G. Kazakov on 06.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#include <string>
#include <vector>
#include <sys/dirent.h>

class FSEventsDirUpdate
{
public:
    static FSEventsDirUpdate *Inst();
 
    bool AddWatchPath(const char *_path);
    bool RemoveWatchPath(const char *_path);
    
private:
    struct WatchData
    {
        std::string path; // should include trailing slash
        FSEventStreamRef stream;
        int refcount;
        bool running;
    };
    std::vector<WatchData*> m_Watches;
        
    FSEventsDirUpdate();
    static void FSEventsDirUpdateCallback(ConstFSEventStreamRef streamRef,
                                          void *userData,
                                          size_t numEvents,
                                          void *eventPaths,
                                          const FSEventStreamEventFlags eventFlags[],
                                          const FSEventStreamEventId eventIds[]);
    void UpdateCallback(ConstFSEventStreamRef streamRef,
                                   void *userData,
                                   size_t numEvents,
                                   void *eventPaths,
                                   const FSEventStreamEventFlags eventFlags[],
                                   const FSEventStreamEventId eventIds[]);
};

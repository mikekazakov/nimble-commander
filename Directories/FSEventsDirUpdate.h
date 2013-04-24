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
 
    unsigned long AddWatchPath(const char *_path);
    // zero returned value means error. any others - valid observation tickets
    
    bool RemoveWatchPath(const char *_path); // will call GetRealPath implicitly - it's not too fast.
    bool RemoveWatchPathWithTicket(unsigned long _ticket); // it's better to use this method
    
private:
    struct WatchData
    {
        std::string path; // should include trailing slash
        FSEventStreamRef stream;
        unsigned long ticket;
        int refcount;
    };
    std::vector<WatchData*> m_Watches;
    unsigned long           m_LastTicket;
        
    FSEventsDirUpdate();
    static void FSEventsDirUpdateCallback(ConstFSEventStreamRef streamRef,
                                          void *userData,
                                          size_t numEvents,
                                          void *eventPaths,
                                          const FSEventStreamEventFlags eventFlags[],
                                          const FSEventStreamEventId eventIds[]);
};

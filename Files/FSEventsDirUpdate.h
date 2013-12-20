//
//  FSEventsDirUpdate.h
//  Directories
//
//  Created by Michael G. Kazakov on 06.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import <DiskArbitration/DiskArbitration.h>
#include <string>
#include <vector>
#include <sys/dirent.h>

using namespace std;

class FSEventsDirUpdate
{
public:
    static FSEventsDirUpdate *Inst();
 
    unsigned long AddWatchPath(const char *_path, void (^_handler)());
    // zero returned value means error. any others - valid observation tickets
    
    bool RemoveWatchPathWithTicket(unsigned long _ticket); // it's better to use this method
    
    static void RunDiskArbitration(); // should be called by NSApp once upon starting
    
private:
    struct WatchData
    {
        string path;        // should include trailing slash
        string volume_path; // root path of volume from this path. without trailing slash (except root)
        FSEventStreamRef stream;
        vector<pair<unsigned long, void (^)()> > handlers;
    };
    vector<WatchData*> m_Watches;
    unsigned long           m_LastTicket;
        
    FSEventsDirUpdate();
    static void DiskDisappeared(DADiskRef disk, void *context);
    static void FSEventsDirUpdateCallback(ConstFSEventStreamRef streamRef,
                                          void *userData,
                                          size_t numEvents,
                                          void *eventPaths,
                                          const FSEventStreamEventFlags eventFlags[],
                                          const FSEventStreamEventId eventIds[]);
};

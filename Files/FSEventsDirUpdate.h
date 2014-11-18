//
//  FSEventsDirUpdate.h
//  Directories
//
//  Created by Michael G. Kazakov on 06.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import <DiskArbitration/DiskArbitration.h>

class FSEventsDirUpdate
{
public:
    static FSEventsDirUpdate &Instance();
 
    unsigned long AddWatchPath(const char *_path, function<void()> _handler);
    // zero returned value means error. any others - valid observation tickets
    
    bool RemoveWatchPathWithTicket(unsigned long _ticket); // it's better to use this method
    
    // called exclusevily by NativeFSManager
    void OnVolumeDidUnmount(const string &_on_path);
private:
    struct WatchData
    {
        string path;        // should include trailing slash
        FSEventStreamRef stream;
        vector<pair<unsigned long, function<void()>>> handlers;
    };
    vector<unique_ptr<WatchData>> m_Watches;
    unsigned long                 m_LastTicket = 1; // no tickets #0, since it'is an error code
        
    FSEventsDirUpdate();
    static void DiskDisappeared(DADiskRef disk, void *context);
    static void FSEventsDirUpdateCallback(ConstFSEventStreamRef streamRef,
                                          void *userData,
                                          size_t numEvents,
                                          void *eventPaths,
                                          const FSEventStreamEventFlags eventFlags[],
                                          const FSEventStreamEventId eventIds[]);
};

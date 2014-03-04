//
//  VFSArchiveUnRARHost.h
//  Files
//
//  Created by Michael G. Kazakov on 02.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <map>
#import <list>
#import "VFSHost.h"
#import "VFSFile.h"

struct VFSArchiveUnRAREntry;
struct VFSArchiveUnRARDirectory;

class VFSArchiveUnRARHost : public VFSHost
{
public:
    static const char *Tag;
    VFSArchiveUnRARHost(const char *_junction_path);
    ~VFSArchiveUnRARHost();
    
    virtual const char *FSTag() const override;
    

    int Open(); // flags will be added later
    
    
    // core VFSHost methods
    virtual int FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> *_target,
                                      int _flags,
                                      bool (^_cancel_checker)()) override;
    
    virtual int Stat(const char *_path, VFSStat &_st, int _flags, bool (^_cancel_checker)()) override;    

    
    
private:
    
    int InitialReadFileList(void *_rar_handle);

    VFSArchiveUnRARDirectory *FindOrBuildDirectory(const string& _path_with_tr_sl);
    
    const VFSArchiveUnRAREntry *FindEntry(const string &_full_path);
    
    map<string, VFSArchiveUnRARDirectory>   m_PathToDir; // path to dir with trailing slash -> directory contents
    uint32_t                                m_LastItemUID = 0;
};

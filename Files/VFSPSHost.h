//
//  VFSPSHost.h
//  Files
//
//  Created by Michael G. Kazakov on 26.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <map>
#import <list>
#import <vector>

#import "VFSHost.h"
#import "VFSFile.h"
#import "DispatchQueue.h"

using namespace std;


class VFSPSHost : public VFSHost
{
public:
    VFSPSHost();
    ~VFSPSHost();
    
    static const char *Tag;    
    virtual const char *FSTag() const override;
    
    virtual int FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> *_target,
                                      int _flags,
                                      bool (^_cancel_checker)()) override;
    
    shared_ptr<const VFSPSHost> SharedPtr() const {return static_pointer_cast<const VFSPSHost>(VFSHost::SharedPtr());}
    shared_ptr<VFSPSHost> SharedPtr() {return static_pointer_cast<VFSPSHost>(VFSHost::SharedPtr());}
    
    
    void UpdateCycle();
    struct ProcInfo;
    struct Snapshot;
private:
    static vector<ProcInfo> GetProcs();
    void CommitProcs(vector<ProcInfo> _procs);
    string ProcInfoIntoFile(const ProcInfo& _info);
    
    
    shared_ptr<Snapshot> m_Data;
    SerialQueue         m_UpdateQ;
};

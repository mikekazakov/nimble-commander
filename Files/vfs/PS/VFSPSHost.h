//
//  VFSPSHost.h
//  Files
//
//  Created by Michael G. Kazakov on 26.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Habanero/DispatchQueue.h>
#include "../VFSHost.h"
#include "../VFSFile.h"


class VFSPSHost : public VFSHost
{
public:
    VFSPSHost();
    ~VFSPSHost();
    
    static const char *Tag;    
    virtual VFSConfiguration Configuration() const override;
    static VFSMeta Meta();
    
    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           VFSCancelChecker _cancel_checker) override;
    
    virtual bool IsDirectory(const char *_path,
                             int _flags,
                             VFSCancelChecker _cancel_checker) override;
    
    virtual int Stat(const char *_path, VFSStat &_st, int _flags, VFSCancelChecker _cancel_checker) override;
    
    virtual int StatFS(const char *_path, VFSStatFS &_stat, VFSCancelChecker _cancel_checker) override;
    
    virtual int FetchFlexibleListing(const char *_path,
                                     shared_ptr<VFSListing> &_target,
                                     int _flags,
                                     VFSCancelChecker _cancel_checker) override;
    
    virtual int IterateDirectoryListing(const char *_path, function<bool(const VFSDirEnt &_dirent)> _handler) override;
    
    virtual bool IsDirChangeObservingAvailable(const char *_path) override;    
    virtual VFSHostDirObservationTicket DirChangeObserve(const char *_path, function<void()> _handler) override;
    virtual void StopDirChangeObserving(unsigned long _ticket) override;
    bool ShouldProduceThumbnails() const override;    
    
    /**
     * Since there's no meaning for having more than one of this FS - this is a caching creation.
     * If there's a living fs already - it will return it, if - will create new.
     * It will store a weak ptr and will not extend FS living time.
     */
    static shared_ptr<VFSPSHost> GetSharedOrNew();
    
    shared_ptr<const VFSPSHost> SharedPtr() const {return static_pointer_cast<const VFSPSHost>(VFSHost::SharedPtr());}
    shared_ptr<VFSPSHost> SharedPtr() {return static_pointer_cast<VFSPSHost>(VFSHost::SharedPtr());}
    
    struct ProcInfo;
    struct Snapshot;
private:
    void UpdateCycle();
    void EnsureUpdateRunning();
    int ProcIndexFromFilepath(const char *_filepath);
    
    
    
    static vector<ProcInfo> GetProcs();
    void CommitProcs(vector<ProcInfo> _procs);
    static string ProcInfoIntoFile(const ProcInfo& _info, shared_ptr<Snapshot> _data);
    
    
    mutex               m_Lock; // bad and ugly, ok.
    shared_ptr<Snapshot> m_Data;
    vector<pair<unsigned long, function<void()>>> m_UpdateHandlers;
    unsigned long       m_LastTicket = 1;
    SerialQueue         m_UpdateQ;
    bool                m_UpdateStarted = false;
};

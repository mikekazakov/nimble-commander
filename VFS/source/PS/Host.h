// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/SerialQueue.h>
#include <VFS/Host.h>
#include <VFS/VFSFile.h>

namespace nc::vfs {

class PSHost final : public Host
{
public:
    PSHost();
    ~PSHost();
    
    static const char *UniqueTag;    
    virtual VFSConfiguration Configuration() const override;
    static VFSMeta Meta();
    
    virtual int CreateFile(const char* _path,
                           std::shared_ptr<VFSFile> &_target,
                           const VFSCancelChecker &_cancel_checker) override;
    
    virtual bool IsDirectory(const char *_path,
                             unsigned long _flags,
                             const VFSCancelChecker &_cancel_checker) override;
    
    virtual int Stat(const char *_path, VFSStat &_st, unsigned long _flags, const VFSCancelChecker &_cancel_checker) override;
    
    virtual int StatFS(const char *_path, VFSStatFS &_stat, const VFSCancelChecker &_cancel_checker) override;
    
    virtual int Unlink(const char *_path, const VFSCancelChecker &_cancel_checker = nullptr) override;
    
    virtual int FetchDirectoryListing(const char *_path,
                                      std::shared_ptr<VFSListing> &_target,
                                      unsigned long _flags,
                                      const VFSCancelChecker &_cancel_checker) override;
    
    virtual int IterateDirectoryListing(const char *_path,
                                        const std::function<bool(const VFSDirEnt &_dirent)> &_handler) override;
    
    virtual bool IsDirChangeObservingAvailable(const char *_path) override;    
    virtual HostDirObservationTicket DirChangeObserve(const char *_path,
                                                      std::function<void()> _handler) override;
    virtual void StopDirChangeObserving(unsigned long _ticket) override;
    
    /**
     * Since there's no meaning for having more than one of this FS - this is a caching creation.
     * If there's a living fs already - it will return it, if - will create new.
     * It will store a weak ptr and will not extend FS living time.
     */
    static std::shared_ptr<PSHost> GetSharedOrNew();
    
    std::shared_ptr<const PSHost> SharedPtr() const {return std::static_pointer_cast<const PSHost>(Host::SharedPtr());}
    std::shared_ptr<PSHost> SharedPtr() {return std::static_pointer_cast<PSHost>(Host::SharedPtr());}
    
    struct ProcInfo;
    struct Snapshot;
private:
    void UpdateCycle();
    void EnsureUpdateRunning();
    int ProcIndexFromFilepath_Unlocked(const char *_filepath);
    
    static std::vector<ProcInfo> GetProcs();
    void CommitProcs(std::vector<ProcInfo> _procs);
    static std::string ProcInfoIntoFile(const ProcInfo& _info, std::shared_ptr<Snapshot> _data);
    
    
    std::mutex           m_Lock; // bad and ugly, ok.
    std::shared_ptr<Snapshot> m_Data;
    std::vector<std::pair<unsigned long, std::function<void()>>> m_UpdateHandlers;
    unsigned long       m_LastTicket = 1;
    SerialQueue         m_UpdateQ;
    bool                m_UpdateStarted = false;
};

}

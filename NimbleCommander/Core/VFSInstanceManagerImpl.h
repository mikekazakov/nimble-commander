// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "VFSInstanceManager.h"
#include "VFSInstancePromise.h"

namespace nc::core {

class VFSInstanceManagerImpl : public VFSInstanceManager
{
public:
    using ObservationTicket = ObservableBase::ObservationTicket;
    using Promise = VFSInstancePromise;
    
    VFSInstanceManagerImpl();
    ~VFSInstanceManagerImpl();
    
    /**
     * Will register information about the instance if not yet.
     * Returned promise may be used for later vfs restoration.
     */
    Promise TameVFS( const shared_ptr<VFSHost>& _instance );
    
    /**
     * Returns a promise for specified vfs, if the information is available.
     */
    Promise PreserveVFS( const weak_ptr<VFSHost>& _instance );
    
    /**
     * Will return and alive instance if it's alive, will try to recreate it (will all upchain) if otherwise.
     * May throw vfs exceptions on vfs rebuilding.
     * May return nullptr on failure.
     */
    shared_ptr<VFSHost> RetrieveVFS( const Promise &_promise, function<bool()> _cancel_checker = nullptr );
    
    /**
     * Will find an info for promise and return a corresponding vfs tag.
     */
    const char *GetTag( const Promise &_promise );
    
    /**
     * Will return empty promise if there's no parent vfs, or it was somehow not registered
     */
    Promise GetParentPromise( const Promise &_promise );
    
    /**
     * Will return empty string on any errors.
     */
    string GetVerboseVFSTitle( const Promise &_promise );
    
    vector<weak_ptr<VFSHost>> AliveHosts();
    
    unsigned KnownVFSCount();
    Promise GetVFSPromiseByPosition( unsigned _at);
    
    ObservationTicket ObserveAliveVFSListChanged( function<void()> _callback );
    ObservationTicket ObserveKnownVFSListChanged( function<void()> _callback );
    
private:
    enum : uint64_t {
        AliveVFSListObservation = 0x0001,
        KnownVFSListObservation = 0x0002,
    };
    
    struct Info;
    
    /**
     * Thread-safe.
     */
    void IncPromiseCount(uint64_t _inst_id);
    
    /**
     * Thread-safe.
     */
    void DecPromiseCount(uint64_t _inst_id);
    
    /**
     * Thread-safe.
     */
    void EnrollAliveHost( const shared_ptr<VFSHost>& _inst );
    
    /**
     * Thread-safe.
     */
    void SweepDeadReferences();
    
    /**
     * Thread-safe.
     */
    void SweepDeadMemory();
    
    Promise SpawnPromiseFromInfo_Unlocked( Info &_info );
    Info *InfoFromVFSWeakPtr_Unlocked(const weak_ptr<VFSHost> &_ptr);
    Info *InfoFromVFSPtr_Unlocked(const shared_ptr<VFSHost> &_ptr);
    Info *InfoFromID_Unlocked(uint64_t _inst_id);
    
    shared_ptr<VFSHost> GetOrRestoreVFS_Unlocked( Info *_info, const function<bool()> &_cancel_checker );
    
    
    vector<Info>                m_Memory;
    uint64_t                    m_MemoryNextID = 1;
    spinlock                    m_MemoryLock;
    
    vector<weak_ptr<VFSHost>>   m_AliveHosts;
    spinlock                    m_AliveHostsLock;
};

}

// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS_fwd.h>
#include <Habanero/Observable.h>

class VFSConfiguration;

namespace nc::core {

class VFSInstancePromise;
    
/**
 * Keeps track of alive VFS in the system.
 * Can give promise to return an alive VFS or try to rebuilt an alive instance from saved VFSConfiguration.
 * All public API is thread-safe.
 * Instances of this class are supposed to live forever, as spawned promises don't prolong the 
 * lifetime of the manager object.
 */
class VFSInstanceManager : protected ObservableBase
{
public:
    using ObservationTicket = ObservableBase::ObservationTicket;
    using Promise = VFSInstancePromise;

    virtual ~VFSInstanceManager() = default;
    
    /**
     * Will register information about the instance if not yet.
     * Returned promise may be used for later vfs restoration.
     */
    virtual Promise TameVFS( const shared_ptr<VFSHost>& _instance ) = 0;
    
    /**
     * Returns a promise for specified vfs, if the information is available.
     */
    virtual Promise PreserveVFS( const weak_ptr<VFSHost>& _instance ) = 0;
    
    /**
     * Will return and alive instance if it's alive, will try to recreate it (will all upchain) if otherwise.
     * May throw vfs exceptions on vfs rebuilding.
     * May return nullptr on failure.
     */
    virtual shared_ptr<VFSHost> RetrieveVFS( const Promise &_promise,
                                            function<bool()> _cancel_checker = nullptr ) = 0;
    
    /**
     * Will find an info for promise and return a corresponding vfs tag.
     */
    virtual const char *GetTag( const Promise &_promise ) = 0;
    
    /**
     * Will return empty promise if there's no parent vfs, or it was somehow not registered
     */
    virtual Promise GetParentPromise( const Promise &_promise ) = 0;

    /**
     * Will return empty string on any errors.
     */
    virtual string GetVerboseVFSTitle( const Promise &_promise ) = 0;
    
    virtual vector<weak_ptr<VFSHost>> AliveHosts() = 0;
    
    virtual unsigned KnownVFSCount() = 0;
    virtual Promise GetVFSPromiseByPosition( unsigned _at) = 0;
    
    virtual ObservationTicket ObserveAliveVFSListChanged( function<void()> _callback ) = 0;
    virtual ObservationTicket ObserveKnownVFSListChanged( function<void()> _callback ) = 0;
    
protected:
    Promise SpawnPromise(uint64_t _inst_id);
    VFSInstanceManager *InstanceFromPromise(const Promise& _promise);
    
private:
    virtual void IncPromiseCount(uint64_t _inst_id) = 0;
    virtual void DecPromiseCount(uint64_t _inst_id) = 0;
    friend VFSInstancePromise;
};
    
}

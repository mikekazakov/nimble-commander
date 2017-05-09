#pragma once

#include <Habanero/Observable.h>

class VFSHost;
class VFSConfiguration;

/**
 * Keeps track of alive VFS in the system.
 * Can give promise to return an alive VFS or try to rebuilt an alive instance from saved VFSConfiguration.
 * All public API is thread-safe.
 */
class VFSInstanceManager : public ObservableBase
{
public:
    using ObservationTicket = ObservableBase::ObservationTicket;
    struct Promise;

    static VFSInstanceManager& Instance();
    
    /**
     * Will register information about the instance if not yet.
     * Returned promise may be used for later vfs restoration.
     */
    Promise TameVFS( const shared_ptr<VFSHost>& _instance );
    
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
    
    
    friend struct Promise;
};

struct VFSInstanceManager::Promise
{
    Promise();
    Promise(Promise &&_rhs);
    Promise(const Promise &_rhs);
    ~Promise();
    const Promise& operator=(const Promise &_rhs);
    const Promise& operator=(Promise &&_rhs);
    operator bool() const noexcept;
    bool operator ==(const Promise &_rhs) const noexcept;
    bool operator !=(const Promise &_rhs) const noexcept;
    const char *tag() const; // may return ""
    string verbose_title() const; // may return ""
    uint64_t id() const;
private:
    Promise(uint64_t _inst_id, VFSInstanceManager &_manager);
    uint64_t            inst_id;
    VFSInstanceManager *manager;
    friend class VFSInstanceManager;
};

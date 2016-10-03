#pragma once

#include <Habanero/Observable.h>
#include <VFS/VFS.h>

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
    Promise TameVFS( const VFSHostPtr& _instance );
    
    Promise PreserveVFS( const weak_ptr<VFSHost>& _instance );
    
    /**
     * Will return and alive instance if it's alive, will try to recreate it (will all upchain) if otherwise.
     * May throw vfs exceptions on vfs rebuilding.
     * May return nullptr on failure.
     */
    VFSHostPtr RetrieveVFS( const Promise &_promise, function<bool()> _cancel_checker = nullptr );
    
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
   
    struct Info
    {
        Info(const VFSHostPtr& _host,
             uint64_t _id,
             uint64_t _parent_id,
             VFSConfiguration _config
             );
        uint64_t            m_ID;
        uint64_t            m_PromisesCount; // combined from Promise instances and links via .m_ParentVFSID
        uint64_t            m_ParentVFSID; // zero means no parent vfs info
        weak_ptr<VFSHost>   m_WeakHost; // need to think about clearing this weak_ptr, so host's memory can be freed        
        VFSConfiguration    m_Configuration;
    };
    
    
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
    void EnrollAliveHost( const VFSHostPtr& _inst );
    
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
    Info *InfoFromVFSPtr_Unlocked(const VFSHostPtr &_ptr);
    Info *InfoFromID_Unlocked(uint64_t _inst_id);
    
    VFSHostPtr GetOrRestoreVFS_Unlocked( Info *_info, const function<bool()> &_cancel_checker );
    
    
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

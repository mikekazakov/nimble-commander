#pragma once


#include "../../Files/VFS/vfs.h"

/**
 * Keeps track of alive VFS in the system.
 * Can give promise to return an alive VFS or try to rebuilt an alive instance from saved VFSConfiguration.
 * All public API is thread-safe.
 */
class VFSInstanceManager
{
public:
    struct Promise
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
    private:
        Promise(uint64_t _inst_id, VFSInstanceManager &_manager);
        uint64_t            inst_id;
        VFSInstanceManager *manager;
        friend class VFSInstanceManager;
    };

    static VFSInstanceManager& Instance();
    
    Promise TameVFS( const VFSHostPtr& _instance );
    
    /**
     * Will return and alive instance if it's alive, will try to recreate it (will all upchain) if otherwise.
     * May throw vfs exceptions on vfs rebuilding.
     * May return nullptr on failure.
     */
    VFSHostPtr RetrieveVFS( const Promise &_promise, function<bool()> _cancel_checker = nullptr );
    
    
    // get alive vfs list


    
private:
   
    struct Info
    {
        Info(const VFSHostPtr& _host,
             uint64_t _id,
             uint64_t _parent_id,
             VFSConfiguration _config
             );
        weak_ptr<VFSHost>   m_WeakHost; // need to think about clearing this weak_ptr, so host's memory can be freed
        uint64_t            m_ID;
        uint32_t            m_PromisesCount; // combined from Promise instances and links via .m_ParentVFSID
        uint64_t            m_ParentVFSID; // zero means no parent vfs info
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
    
    
    Info *InfoFromVFSPtr_Unlocked(const VFSHostPtr &_ptr);
    Info *InfoFromID_Unlocked(uint64_t _inst_id);
    
    VFSHostPtr GetOrRestoreVFS_Unlocked( Info *_info );
    
    atomic_ulong    m_NextID{1};
    
    
    vector<Info>                m_Memory;
    spinlock                    m_MemoryLock;
    
    vector<weak_ptr<VFSHost>>   m_AliveHosts;
    spinlock                    m_AliveHostsLock;
    
    
    friend struct Promise;
};

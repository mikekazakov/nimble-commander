#include "VFSInstanceManager.h"

/////////////////////////////////////////////////////////
////////////// VFSInstanceManager::Promise //////////////
/////////////////////////////////////////////////////////

VFSInstanceManager::Promise::Promise():
    inst_id(0),
    manager(nullptr)
{
}

VFSInstanceManager::Promise::Promise(uint64_t _inst_id, VFSInstanceManager &_manager):
    inst_id(_inst_id),
    manager(&_manager)
{ /* here assumes that producing manager will perform initial increment himself. */}

VFSInstanceManager::Promise::~Promise()
{
    if(manager) manager->DecPromiseCount(inst_id);
}

VFSInstanceManager::Promise::Promise(Promise &&_rhs):
    inst_id(_rhs.inst_id),
    manager(_rhs.manager)
{
    _rhs.inst_id = 0;
    _rhs.manager = nullptr;
}

VFSInstanceManager::Promise::Promise(const Promise &_rhs):
    inst_id(_rhs.inst_id),
    manager(_rhs.manager)
{
    if(manager) manager->IncPromiseCount(inst_id);
}

const VFSInstanceManager::Promise& VFSInstanceManager::Promise::operator=(const Promise &_rhs)
{
    if(manager) manager->DecPromiseCount(inst_id);
    inst_id = _rhs.inst_id;
    manager = _rhs.manager;
    if(manager) manager->IncPromiseCount(inst_id);
    return *this;
}

const VFSInstanceManager::Promise& VFSInstanceManager::Promise::operator=(Promise &&_rhs)
{
    if(manager) manager->DecPromiseCount(inst_id);
    inst_id = _rhs.inst_id;
    manager = _rhs.manager;
    _rhs.inst_id = 0;
    _rhs.manager = nullptr;
    return *this;
}

VFSInstanceManager::Promise::operator bool() const noexcept
{
    return manager != nullptr && inst_id != 0;
}

bool VFSInstanceManager::Promise::operator ==(const Promise &_rhs) const noexcept
{
    return manager == _rhs.manager && inst_id == _rhs.inst_id;
}

bool VFSInstanceManager::Promise::operator !=(const Promise &_rhs) const noexcept
{
    return !(*this == _rhs);
}


/////////////////////////////////////////////////////////
////////////// VFSInstanceManager::Info /////////////////
/////////////////////////////////////////////////////////

VFSInstanceManager::Info::Info(const VFSHostPtr& _host,
                               uint64_t _id,
                               uint64_t _parent_id,
                               VFSConfiguration _config
                               ):
    m_WeakHost(_host),
    m_ID(_id),
    m_ParentVFSID(_parent_id),
    m_Configuration(_config),
    m_PromisesCount(0)
{
}

////////////////////////////////////////////////
////////////// VFSInstanceManager //////////////
////////////////////////////////////////////////

VFSInstanceManager& VFSInstanceManager::Instance()
{
    static auto inst = new VFSInstanceManager;
    return *inst;
}

VFSInstanceManager::Promise VFSInstanceManager::TameVFS( const VFSHostPtr& _instance )
{
    if( !_instance )
        return {};
    
    auto instance = _instance;
    
    LOCK_GUARD(m_MemoryLock) {
        if( auto info = InfoFromVFSPtr_Unlocked(instance) ) {
            // we already have this VFS, need to simply increase refcount and return a promise
            info->m_PromisesCount++;
            return Promise(info->m_ID, *this);
        }
    }
    
    if( instance->Parent() )
        TameVFS( instance->Parent() );
    
    EnrollAliveHost(instance);
    
    LOCK_GUARD(m_MemoryLock) {
        // create new VFS info
        
        uint64_t parent_id = 0;
        if( instance->Parent() ) {
            if( auto parent_info = InfoFromVFSPtr_Unlocked(instance->Parent()) ) {
                parent_id = parent_info->m_ID;
                parent_info->m_PromisesCount++;
            }
            else
                assert(0); // logic error - should never happen
        }
        
        Info info{ instance, m_NextID++, parent_id, instance->Configuration() };
        info.m_PromisesCount = 1;
    
        m_Memory.emplace_back(info);
    
        instance->SetDesctructCallback([=](const VFSHost*){
            SweepDeadReferences();
            SweepDeadMemory();
        });
        
        return Promise(info.m_ID, *this);
    }
    return {}; // not reaching here.
}

void VFSInstanceManager::IncPromiseCount(uint64_t _inst_id)
{
    if( _inst_id == 0 )
        return;
    
    LOCK_GUARD(m_MemoryLock)
        if( auto info = InfoFromID_Unlocked(_inst_id) )
            info->m_PromisesCount++;
}

void VFSInstanceManager::DecPromiseCount(uint64_t _inst_id)
{
    if( _inst_id == 0 )
        return;

    LOCK_GUARD(m_MemoryLock)
        if( auto info = InfoFromID_Unlocked(_inst_id) ) {
            assert( info->m_PromisesCount > 0 );
            info->m_PromisesCount--;
        
            if( info->m_PromisesCount == 0 ) {
                if( info->m_WeakHost.expired() ) {
                    // now remove this vfs info - nobody want's it any longer
                    
                    if( info->m_ParentVFSID > 0 ) {
                        // remove refcount on parent vfs
                        auto id_to_dec = info->m_ParentVFSID;
                        dispatch_to_background([=]{
                            DecPromiseCount( id_to_dec );
                        });
                    }
                    
                    m_Memory.erase( next(begin(m_Memory), info - m_Memory.data()) );
                }
            }
        }
}

VFSInstanceManager::Info *VFSInstanceManager::InfoFromVFSPtr_Unlocked(const VFSHostPtr &_ptr)
{
    if( !_ptr )
        return nullptr;
    for( auto &i: m_Memory )
        if( !i.m_WeakHost.owner_before(_ptr) && !_ptr.owner_before(i.m_WeakHost) )
            return &i;
    return nullptr;
}

VFSInstanceManager::Info *VFSInstanceManager::InfoFromID_Unlocked(uint64_t _inst_id)
{
    for( auto &i: m_Memory )
        if( i.m_ID == _inst_id )
            return &i;
    return nullptr;
}

// remove memory if:
// 1. restoration promises count == 0
// 2. there's no strong references to vfs instance
void VFSInstanceManager::SweepDeadMemory()
{
    LOCK_GUARD(m_MemoryLock) {
        m_Memory.erase(
                       remove_if(begin(m_Memory),
                                 end(m_Memory),
                                 [](const auto &i){ return i.m_WeakHost.expired() && i.m_PromisesCount == 0; }),
                       end(m_Memory));
    }
}

void VFSInstanceManager::EnrollAliveHost( const VFSHostPtr& _inst )
{
    if( !_inst )
        return;
    
    LOCK_GUARD(m_AliveHostsLock) {
        if( any_of(begin(m_AliveHosts),
                   end(m_AliveHosts),
                   [&](auto &_i){ return !_i.owner_before(_inst) && !_inst.owner_before(_i);}) )
           return;
        
        m_AliveHosts.emplace_back( _inst );
    }
}

void VFSInstanceManager::SweepDeadReferences()
{
    LOCK_GUARD(m_AliveHostsLock) {
        m_AliveHosts.erase(
                           remove_if(begin(m_AliveHosts),
                                     end(m_AliveHosts),
                                     [](auto &i){ return i.expired(); }),
                           end(m_AliveHosts));
    }
}

VFSHostPtr VFSInstanceManager::RetrieveVFS( const Promise &_promise, function<bool()> _cancel_checker )
{
    if( !_promise )
        return nullptr;
    assert( _promise.manager == this );
    
    LOCK_GUARD(m_MemoryLock) {
        auto info = InfoFromID_Unlocked( _promise.inst_id );
        if( !info )
            return nullptr; // this should never happen!
        
        return GetOrRestoreVFS_Unlocked(info);
    }
    return nullptr;
}

// assumes that m_MemoryLock is aquired
VFSHostPtr VFSInstanceManager::GetOrRestoreVFS_Unlocked( Info *_info )
{
    // check if host is alive - in this case we can return it immediately
    if( auto host = _info->m_WeakHost.lock() )
        return host;
    
    // nope - need to restore host(s)
    VFSHostPtr parent_host = nullptr;
    if( _info->m_ParentVFSID > 0 ) {
        auto parent_info = InfoFromID_Unlocked( _info->m_ParentVFSID );
        if( !parent_info )
            return nullptr; // this should never happen!
        
        parent_host = GetOrRestoreVFS_Unlocked( parent_info ); // may throw here
    }
    
    auto vfs_meta = VFSFactory::Instance().Find( _info->m_Configuration.Tag() );
    if( !vfs_meta )
        return nullptr; // unregistered vfs???
    
    auto host = vfs_meta->SpawnWithConfig(parent_host, _info->m_Configuration); // may throw here
    if( host ) {
        _info->m_WeakHost = host;
        EnrollAliveHost(host);
    }
    
    return host;
}

// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/algo.h>
#include "VFSInstanceManagerImpl.h"
#include <VFS/VFS.h>

namespace nc::core {

struct VFSInstanceManagerImpl::Info
{
    Info(const shared_ptr<VFSHost>& _host,
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

VFSInstanceManagerImpl::Info::Info(const VFSHostPtr& _host,
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

VFSInstanceManagerImpl::VFSInstanceManagerImpl()
{
}
    
VFSInstanceManagerImpl::~VFSInstanceManagerImpl()
{
    cerr << "VFSInstanceManager instances must live forever!" << endl;
}
    
VFSInstanceManager::Promise VFSInstanceManagerImpl::TameVFS( const VFSHostPtr& _instance )
{
    if( !_instance )
        return {};
    
    LOCK_GUARD(m_MemoryLock) {
        // check if we have a weak_ptr to this instance
        // most of calls should end on this check:
        if( auto info = InfoFromVFSPtr_Unlocked(_instance) )
            return SpawnPromiseFromInfo_Unlocked( *info ); // we already have this VFS, need to simply increase refcount and return a promise
      
        // check if we have this vfs before, but it was destroyed.
        // in this case we can just update an existing information, so all previous promises will point at a new _instance
        vector<Info*> existing_match;
        uint64_t info_id_request = 0;
        VFSHostPtr instance_recursive = _instance;
        while( instance_recursive  ) {
            bool has_exising_match = false;
            auto instance_config = instance_recursive->Configuration();
            // find an info with matching configuration and requestd id
            for( auto &i: m_Memory )
                if( i.m_Configuration == instance_config &&
                   (info_id_request == 0 ?
                        i.m_WeakHost.expired() : // for frontmost vfs we should check that this filesystem was destroyed
                        i.m_ID == info_id_request)
                   ) {
                    // need to check if there's an uplink to parent if needed, and only if needed
                    if( (i.m_ParentVFSID == 0 && !instance_recursive->Parent()) ||
                        (i.m_ParentVFSID != 0 &&  instance_recursive->Parent()) ) {
                       
                        info_id_request = i.m_ParentVFSID; // may be zero here, intended
                        existing_match.emplace_back( &i );
                        has_exising_match = true;
                        break;
                    }
                }
            
            if( !has_exising_match )
                break;
            instance_recursive = instance_recursive->Parent();
        }
        
        if( !instance_recursive ) {
            // we have found a matching existing information chain, need to refresh hosts pointers
            instance_recursive = _instance;
            for( auto &i: existing_match ) {
                if( i->m_WeakHost.expired() ) {
                    i->m_WeakHost = instance_recursive;
                    EnrollAliveHost(instance_recursive);
                }
                instance_recursive = instance_recursive->Parent();
            }
            assert( instance_recursive == nullptr ); // logic check

            return SpawnPromiseFromInfo_Unlocked( *existing_match.front() );
        }
    }
    
    // no such exising info found, need to build it
    auto instance = _instance;
    
    if( instance->Parent() )
        TameVFS( instance->Parent() );
    
    EnrollAliveHost(instance);
    
    Promise result;
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
        
        m_Memory.emplace_back( instance, m_MemoryNextID++, parent_id, instance->Configuration() );
        result = SpawnPromiseFromInfo_Unlocked( m_Memory.back() );
    }

    FireObservers( KnownVFSListObservation );
    
    return result;
}

VFSInstanceManager::Promise VFSInstanceManagerImpl::PreserveVFS( const weak_ptr<VFSHost>& _instance )
{
    LOCK_GUARD(m_MemoryLock) {
        // check if we have a weak_ptr to this instance
        // most of calls should end on this check:
        if( auto info = InfoFromVFSWeakPtr_Unlocked(_instance) )
            return SpawnPromiseFromInfo_Unlocked(*info); // we already have this VFS, need to simply increase refcount and return a promise
    }
    return {};
}

void VFSInstanceManagerImpl::IncPromiseCount(uint64_t _inst_id)
{
    if( _inst_id == 0 )
        return;
    
    LOCK_GUARD(m_MemoryLock)
        if( auto info = InfoFromID_Unlocked(_inst_id) )
            info->m_PromisesCount++;
}

void VFSInstanceManagerImpl::DecPromiseCount(uint64_t _inst_id)
{
    if( _inst_id == 0 )
        return;

    bool fire_observers = false;
    
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
                    fire_observers = true;
                }
            }
        }

    if( fire_observers )
        FireObservers( KnownVFSListObservation );
}

VFSInstanceManagerImpl::Info *VFSInstanceManagerImpl::InfoFromVFSWeakPtr_Unlocked(const weak_ptr<VFSHost> &_ptr)
{
    for( auto &i: m_Memory )
        if( !i.m_WeakHost.owner_before(_ptr) && !_ptr.owner_before(i.m_WeakHost) )
            return &i;
    return nullptr;
}

VFSInstanceManagerImpl::Info *VFSInstanceManagerImpl::InfoFromVFSPtr_Unlocked(const VFSHostPtr &_ptr)
{
    if( !_ptr )
        return nullptr;
    for( auto &i: m_Memory )
        if( !i.m_WeakHost.owner_before(_ptr) && !_ptr.owner_before(i.m_WeakHost) )
            return &i;
    return nullptr;
}

VFSInstanceManagerImpl::Info *VFSInstanceManagerImpl::InfoFromID_Unlocked(uint64_t _inst_id)
{
    for( auto &i: m_Memory )
        if( i.m_ID == _inst_id )
            return &i;
    return nullptr;
}

// remove memory if:
// 1. restoration promises count == 0
// 2. there's no strong references to vfs instance
void VFSInstanceManagerImpl::SweepDeadMemory()
{
    LOCK_GUARD(m_MemoryLock) {
        auto old_size = m_Memory.size();
        m_Memory.erase(
                       remove_if(begin(m_Memory),
                                 end(m_Memory),
                                 [](const auto &i){ return i.m_WeakHost.expired() && i.m_PromisesCount == 0; }),
                       end(m_Memory));
        
        for( auto &i: m_Memory )
            if( i.m_WeakHost.expired() )
                i.m_WeakHost.reset();
        
        if( old_size == m_Memory.size() )
            return; // no changes
    }
    
    FireObservers( KnownVFSListObservation );
}

void VFSInstanceManagerImpl::EnrollAliveHost( const VFSHostPtr& _inst )
{
    if( !_inst )
        return;
    
    LOCK_GUARD(m_AliveHostsLock) {
        if( any_of(begin(m_AliveHosts),
                   end(m_AliveHosts),
                   [&](auto &_i){ return !_i.owner_before(_inst) && !_inst.owner_before(_i);}) )
           return;
        
        m_AliveHosts.emplace_back( _inst );
        _inst->SetDesctructCallback([=](const VFSHost*){
            SweepDeadReferences();
            SweepDeadMemory();
        });
    }
    FireObservers( AliveVFSListObservation ); // tell that we have added a vfs to alive list
}

void VFSInstanceManagerImpl::SweepDeadReferences()
{
    LOCK_GUARD(m_AliveHostsLock) {
        auto old_size = m_AliveHosts.size();
        m_AliveHosts.erase(
                           remove_if(begin(m_AliveHosts),
                                     end(m_AliveHosts),
                                     [](auto &i){ return i.expired(); }),
                           end(m_AliveHosts));
        if( old_size == m_AliveHosts.size() )
            return; // no changes
    }
    FireObservers( AliveVFSListObservation ); // tell that we have removed some vfs from alive list
}

VFSHostPtr VFSInstanceManagerImpl::RetrieveVFS( const Promise &_promise, function<bool()> _cancel_checker )
{
    if( !_promise )
        return nullptr;
    assert(  InstanceFromPromise(_promise) == this );
    
    LOCK_GUARD(m_MemoryLock) {
        auto info = InfoFromID_Unlocked( _promise.id() );
        if( !info )
            return nullptr; // this should never happen!
        
        return GetOrRestoreVFS_Unlocked(info, _cancel_checker);
    }
    return nullptr;
}

unsigned VFSInstanceManagerImpl::KnownVFSCount()
{
    LOCK_GUARD(m_MemoryLock) {
        return (unsigned)m_Memory.size();
    }
    return 0;
}

VFSInstanceManager::Promise VFSInstanceManagerImpl::GetVFSPromiseByPosition( unsigned _at )
{
    LOCK_GUARD(m_MemoryLock)
        if( _at < m_Memory.size() )
            return SpawnPromiseFromInfo_Unlocked( m_Memory[_at] );
    return {};
}

VFSInstanceManager::Promise VFSInstanceManagerImpl::GetParentPromise( const Promise &_promise )
{
    if( !_promise )
        return {};
    assert( InstanceFromPromise(_promise) == this );
    
    
    LOCK_GUARD(m_MemoryLock) {
        auto info = InfoFromID_Unlocked( _promise.id() );
        if( !info || info->m_ParentVFSID == 0 )
            return {};
        
        if( auto parent_info = InfoFromID_Unlocked( info->m_ParentVFSID ) )
            return SpawnPromiseFromInfo_Unlocked( *parent_info );
    }
    return {};
}

const char *VFSInstanceManagerImpl::GetTag( const Promise &_promise )
{
    if( !_promise )
        return nullptr;
    assert( InstanceFromPromise(_promise) == this );
    
    LOCK_GUARD(m_MemoryLock) {
        auto info = InfoFromID_Unlocked( _promise.id() );
        if( !info )
            return nullptr; // this should never happen!
        
        return info->m_Configuration.Tag();
    }
    return nullptr;
}

// assumes that m_MemoryLock is aquired
VFSHostPtr VFSInstanceManagerImpl::GetOrRestoreVFS_Unlocked( Info *_info, const function<bool()> &_cancel_checker )
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
        
        parent_host = GetOrRestoreVFS_Unlocked( parent_info, _cancel_checker ); // may throw here
    }
    
    // find meta information about vfs so we can recreate it
    auto vfs_meta = VFSFactory::Instance().Find( _info->m_Configuration.Tag() );
    if( !vfs_meta )
        return nullptr; // unregistered vfs???
    
    // try to recreate a vfs
    auto host = vfs_meta->SpawnWithConfig( parent_host, _info->m_Configuration, _cancel_checker ); // may throw here
    if( host ) {
        _info->m_WeakHost = host;
        EnrollAliveHost(host);
    }
    
    return host;
}

string VFSInstanceManagerImpl::GetVerboseVFSTitle( const Promise &_promise )
{
    if( !_promise )
        return "";
    assert( InstanceFromPromise(_promise) == this );
    
    LOCK_GUARD(m_MemoryLock) {
        string title;
        uint64_t next = _promise.id();
        while( next > 0 ) {
            auto info = InfoFromID_Unlocked( next );
            if( !info )
                return ""; // this should never happen!
            
            title.insert(0, info->m_Configuration.VerboseJunction());
            next = info->m_ParentVFSID;
        }
        
        return title;
    }
    return "'";
}

VFSInstanceManager::ObservationTicket VFSInstanceManagerImpl::ObserveAliveVFSListChanged( function<void()> _callback )
{
    return AddObserver(move(_callback), AliveVFSListObservation);
}

VFSInstanceManager::ObservationTicket VFSInstanceManagerImpl::ObserveKnownVFSListChanged( function<void()> _callback )
{
    return AddObserver(move(_callback), KnownVFSListObservation);
}

vector<weak_ptr<VFSHost>> VFSInstanceManagerImpl::AliveHosts()
{
    vector<weak_ptr<VFSHost>> list;
    LOCK_GUARD(m_AliveHostsLock) {
        list = m_AliveHosts;
    }
    return list;
}

// assumes that m_MemoryLock is aquired
VFSInstanceManager::Promise VFSInstanceManagerImpl::SpawnPromiseFromInfo_Unlocked( Info &_info )
{
    _info.m_PromisesCount++;
    return SpawnPromise(_info.m_ID);
}

}

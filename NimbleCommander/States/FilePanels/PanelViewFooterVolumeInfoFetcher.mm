// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/SerialQueue.h>
#include <Habanero/CommonPaths.h>
#include <VFS/Native.h>
#include "PanelViewFooterVolumeInfoFetcher.h"

namespace nc::panel {

using namespace std::literals;
    
template <typename T, typename U>
inline bool equals(const std::weak_ptr<T>& t, const std::weak_ptr<U>& u)
{
    return !t.owner_before(u) && !u.owner_before(t);
}


template <typename T, typename U>
inline bool equals(const std::weak_ptr<T>& t, const std::shared_ptr<U>& u)
{
    return !t.owner_before(u) && !u.owner_before(t);
}

namespace {
struct LookPath
{
    VFSHostWeakPtr                              host;
    std::string                                 path;
    std::vector<FooterVolumeInfoFetcher*>       watchers;
    std::optional<VFSStatFS>                    current;
    bool                                        scheduled = false;
};
}

static std::vector<LookPath> g_Context;
static dispatch_queue g_Queue{ "com.magnumbytes.nimblecommander.footer_fs_stat" };
static const auto g_Delay = 5s;

struct PanelViewFooterVolumeInfoFetcherInternals
{

static void AcceptResult(VFSHostWeakPtr _host,
                         std::string _path,
                         std::optional<VFSStatFS> _stat )
{
    dispatch_assert_main_queue();
    
    for( auto &lp: g_Context )
        if( equals( lp.host, _host ) &&
           lp.path == _path ) {
            lp.scheduled = false;
            
            if( _stat && lp.current != *_stat ) {
                lp.current = *_stat;
                for( auto p: lp.watchers ) {
                    assert( p );
                    if( p->m_Active )
                        p->Accept( *lp.current );
                }
            }
            
            ScheduleIfNeed(lp);
        }
}

static void ScheduleIfNeed( LookPath &_lp, bool _hurry = false)
{
    if( _lp.scheduled )
        return;
    
    VFSHostWeakPtr host = _lp.host;
    std::string path = _lp.path;
    
    g_Queue.after( _hurry ? 0s : g_Delay, [=]{
        VFSStatFS stat;
        int result = -1;
        if( auto h = host.lock() )
            result = h->StatFS(path.c_str(), stat, 0);
        dispatch_to_main_queue([=]{
            AcceptResult( host, path, result == 0 ? std::optional<VFSStatFS>{stat} : std::nullopt );
        });
    });
    
    _lp.scheduled = true;
}

static const VFSStatFS* RegisterWatcher(FooterVolumeInfoFetcher* _w,
                                        const VFSHostWeakPtr &_host,
                                        const std::string& _path )
{
    dispatch_assert_main_queue();
    
    if( _host.expired() )
        return nullptr;
    
    for( auto &lp: g_Context )
        if( equals( lp.host, _host ) &&
           lp.path == _path ) {
            lp.watchers.emplace_back(_w);
            ScheduleIfNeed( lp );
            return lp.current ? &(*lp.current) : nullptr;
        }
    
    LookPath lp;
    lp.host = _host;
    lp.path = _path;
    lp.watchers.emplace_back(_w);
    g_Context.emplace_back( std::move(lp) );
    ScheduleIfNeed( g_Context.back(), true );
    return nullptr;
}
    
static const VFSStatFS* Probe(FooterVolumeInfoFetcher* _w,
                              const VFSHostWeakPtr &_host,
                              const std::string& _path )
{
    dispatch_assert_main_queue();
    
    if( _host.expired() )
        return nullptr;
    
    for( auto &lp: g_Context )
        if( equals( lp.host, _host ) &&
           lp.path == _path )
            return lp.current ? &(*lp.current) : nullptr;
    
    return nullptr;
}

static void RemoveWatcher(FooterVolumeInfoFetcher* _w,
                          const VFSHostWeakPtr &_host,
                          const std::string& _path )
{
    dispatch_assert_main_queue();
    
    const auto it = find_if( begin(g_Context), end(g_Context), [&](auto &lp){
        return equals( lp.host, _host ) && lp.path == _path;
    });
    if( it != end(g_Context) ) {
        const auto i = find( begin(it->watchers), end(it->watchers), _w );
        if( i != end(it->watchers) )
            it->watchers.erase(i);
        
        if( it->watchers.empty() )
            g_Context.erase(it);
    }
}
    
};

FooterVolumeInfoFetcher::FooterVolumeInfoFetcher()
{
    dispatch_assert_main_queue();
    
}

FooterVolumeInfoFetcher::~FooterVolumeInfoFetcher()
{
    dispatch_assert_main_queue();
    PauseUpdates();
}

void FooterVolumeInfoFetcher::SetCallback( std::function<void(const VFSStatFS&)> _callback )
{
    m_Callback = std::move(_callback);
}

void FooterVolumeInfoFetcher::SetTarget( const VFSListingPtr &_listing )
{
    VFSHostPtr current_host;
    std::string current_path;
    if( _listing->IsUniform()  ) {
        // we're in regular directory somewhere
        current_host = _listing->Host();
        current_path = _listing->Directory();
    }
    else {
        // we're in temporary directory so there may be not common path and common host.
        // as current solution - display information about first item's directory
        if( !_listing->Empty() ) {
            current_host = _listing->Host(0);
            current_path = _listing->Directory(0);
        }
        else {
            // there's no first item (no items at all) - display information about home directory
            current_host = VFSNativeHost::SharedHost();
            current_path = CommonPaths::Home();
        }
    }
    
    if( equals(m_Host, current_host) && m_Path == current_path )
        return;
    const bool is_active = IsActive();

    if( is_active )
        PauseUpdates();
    
    m_Host = current_host;
    m_Path = current_path;
    
    if( is_active )
        ResumeUpdates();
    else {
        auto st = PanelViewFooterVolumeInfoFetcherInternals::Probe( this, m_Host, m_Path );
        if( st )
            m_Current = *st;
    }
}

const VFSStatFS& FooterVolumeInfoFetcher::Current() const
{
    return m_Current;
}

bool FooterVolumeInfoFetcher::IsActive() const
{
    return m_Active;
}

void FooterVolumeInfoFetcher::PauseUpdates()
{
    if( m_Active ) {
        PanelViewFooterVolumeInfoFetcherInternals::RemoveWatcher( this, m_Host, m_Path );
        m_Active = false;
    }
}

void FooterVolumeInfoFetcher::ResumeUpdates()
{
    if( !m_Active ) {
        auto st = PanelViewFooterVolumeInfoFetcherInternals::RegisterWatcher( this, m_Host, m_Path );
        if( st )
            m_Current = *st;
        m_Active = true;
    }
}

void FooterVolumeInfoFetcher::Accept( const VFSStatFS &_stat )
{
    m_Current = _stat;
    if( m_Callback )
        m_Callback(m_Current);
}

}

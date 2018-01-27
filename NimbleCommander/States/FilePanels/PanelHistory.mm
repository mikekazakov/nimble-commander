// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelHistory.h"
#include "../../Core/VFSInstanceManager.h"

namespace nc::panel {

bool History::IsRecording() const noexcept
{
    return m_IsRecording;
}

bool History::CanMoveForth() const noexcept
{
    if(m_IsRecording)
        return false;
    if(m_History.size() < 2)
        return false;
    return m_PlayingPosition < m_History.size() - 1;
}

bool History::CanMoveBack() const noexcept
{
    if(m_History.size() < 2)
        return false;
    if(m_IsRecording)
        return true;
    return m_PlayingPosition > 0;
}

void History::MoveForth()
{
    if( !CanMoveForth() )
        throw logic_error("PanelHistory::MoveForth called when CanMoveForth()==false");
    
    if(m_IsRecording) return;
    if(m_History.size() < 2) return;
    if(m_PlayingPosition < m_History.size() - 1)
        m_PlayingPosition++;
}

void History::MoveBack()
{
    if( !CanMoveBack() )
        throw logic_error("PanelHistory::MoveBack called when CanMoveBack()==false");
    
    if(m_IsRecording) {
        m_IsRecording = false;
        m_PlayingPosition = (unsigned)m_History.size() - 2;
    }
    else {
        m_PlayingPosition--;
    }
}

const History::Path* History::CurrentPlaying() const
{
    if( m_IsRecording )
        return nullptr;
    return &*next(begin(m_History), m_PlayingPosition);
}
    
const History::Path* History::MostRecent() const
{
    if( m_IsRecording ) {
        if( !m_History.empty() )
            return &m_History.back();
        return nullptr;
    }
    else {
        assert(m_PlayingPosition < m_History.size());
        return &*next(begin(m_History), m_PlayingPosition);
    }
}

void History::Put(const VFSListing &_listing )
{
    if( _listing.IsUniform() && _listing.Host()->IsNativeFS() )
        m_LastNativeDirectory = _listing.Directory();
    
    const auto adapter = [this](const shared_ptr<VFSHost>&_host) -> core::VFSInstancePromise {
        if( !m_VFSMgr )
            return {};
        return m_VFSMgr->TameVFS(_host);
    };
    ListingPromise promise{_listing, adapter};
    
    if( m_IsRecording ) {
        if( !m_History.empty() && m_History.back() == promise )
            return;
        m_History.emplace_back( move(promise) );
        if( m_History.size() > m_HistoryLength )
            m_History.pop_front();
    }
    else {
        assert(m_PlayingPosition < m_History.size());
        auto i = begin(m_History);
        advance(i, m_PlayingPosition);
        if( *i != promise ) {
            m_IsRecording = true;
            while( m_History.size() > m_PlayingPosition + 1 )
                m_History.pop_back();
            m_History.emplace_back( move(promise) );
        }
    }
}

unsigned History::Length() const noexcept
{
    return (unsigned)m_History.size();
}

bool History::Empty() const noexcept
{
    return m_History.empty();
}
    
vector<reference_wrapper<const History::Path>> History::All() const
{
    vector<reference_wrapper<const Path>> res;
    for( auto &i:m_History )
        res.emplace_back( cref(i) );
    return res;
}

const History::Path* History::RewindAt(size_t _indx)
{
    if(_indx >= m_History.size())
        return nullptr;
    
    m_IsRecording = false;
    m_PlayingPosition = (unsigned)_indx;
    
    return CurrentPlaying();
}

const string &History::LastNativeDirectoryVisited() const noexcept
{
    return m_LastNativeDirectory;
}

void History::SetVFSInstanceManager(core::VFSInstanceManager &_mgr)
{
    m_VFSMgr = &_mgr;
}
    
}

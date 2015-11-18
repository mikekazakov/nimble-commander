//
//  PanelHistory.mm
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "PanelHistory.h"

bool PanelHistory::IsRecording() const noexcept
{
    return m_IsRecording;
}

bool PanelHistory::CanMoveForth() const noexcept
{
    if(m_IsRecording)
        return false;
    if(m_History.size() < 2)
        return false;
    return m_PlayingPosition < m_History.size() - 1;
}

bool PanelHistory::CanMoveBack() const noexcept
{
    if(m_History.size() < 2)
        return false;
    if(m_IsRecording)
        return true;
    return m_PlayingPosition > 0;
}

void PanelHistory::MoveForth()
{
    if( !CanMoveForth() )
        throw logic_error("PanelHistory::MoveForth called when CanMoveForth()==false");
    
    if(m_IsRecording) return;
    if(m_History.size() < 2) return;
    if(m_PlayingPosition < m_History.size() - 1)
        m_PlayingPosition++;
}

void PanelHistory::MoveBack()
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

const VFSPathStack* PanelHistory::Current() const
{
    if( m_IsRecording )
        return nullptr;
    return &*next(begin(m_History), m_PlayingPosition);
}

void PanelHistory::Put(VFSPathStack&& _path)
{
    if( m_IsRecording ) {
        if( !m_History.empty() && m_History.back() == _path )
            return;
        if( !m_History.empty() && m_History.back().weak_equal(_path) )
            m_History.pop_back();
        m_History.emplace_back(move(_path));
        if( m_History.size() > m_HistoryLength )
            m_History.pop_front();
    }
    else {
        assert(m_PlayingPosition < m_History.size());
        auto i = begin(m_History);
        advance(i, m_PlayingPosition);
        if( *i != _path ) {
            if(i->weak_equal(_path)) {
                m_History.insert(m_History.erase(i), move(_path));
            }
            else {
                m_IsRecording = true;
                m_History.resize(m_PlayingPosition + 1);
                m_History.emplace_back(move(_path));
            }
        }
    }
}

unsigned PanelHistory::Length() const noexcept
{
    return (unsigned)m_History.size();
}

bool PanelHistory::Empty() const noexcept
{
    return m_History.empty();
}
    
vector<reference_wrapper<const VFSPathStack>> PanelHistory::All() const
{
    vector<reference_wrapper<const VFSPathStack>> res;
    for( auto &i:m_History )
        res.emplace_back( cref(i) );
    return res;
}

const VFSPathStack* PanelHistory::RewindAt(size_t _indx)
{
    if(_indx >= m_History.size())
        return nullptr;
    
    m_IsRecording = false;
    m_PlayingPosition = (unsigned)_indx;
    
    return Current();
}

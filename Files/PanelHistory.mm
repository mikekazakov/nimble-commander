//
//  PanelHistory.mm
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "PanelHistory.h"

bool PanelHistory::IsRecording() const
{
    return m_IsRecording;
}

bool PanelHistory::CanMoveForth() const
{
    if(m_IsRecording)
        return false;
    if(m_History.size() < 2)
        return false;
    return m_PlayingPosition < m_History.size() - 1;
}

bool PanelHistory::CanMoveBack() const
{
    if(m_History.size() < 2)
        return false;
    if(m_IsRecording)
        return true;
    return m_PlayingPosition > 0;
}

void PanelHistory::MoveForth()
{
   assert(CanMoveForth());
    if(m_IsRecording) return;
    if(m_History.size() < 2) return;
    if(m_PlayingPosition < m_History.size() - 1)
        m_PlayingPosition++;
}

void PanelHistory::MoveBack()
{
    assert(CanMoveBack());
    
    if(m_IsRecording)
    {
        m_IsRecording = false;
        m_PlayingPosition = (unsigned)m_History.size() - 2;
    }
    else
    {
        m_PlayingPosition--;
    }
}

const VFSPathStack* PanelHistory::Current() const
{
    assert(m_IsRecording == false);
    auto i = begin(m_History);
    advance(i, m_PlayingPosition);
    return &*i;
}

void PanelHistory::Put(VFSPathStack&& _path)
{
    if(m_IsRecording)
    {
        if(!m_History.empty() && m_History.back() == _path)
            return;
        if(m_History.back().weak_equal(_path))
            m_History.pop_back();
        m_History.emplace_back(move(_path));
        if(m_History.size() > m_HistoryLength)
            m_History.pop_front();
    }
    else
    {
        assert(m_PlayingPosition < m_History.size());
        auto i = begin(m_History);
        advance(i, m_PlayingPosition);
        if(*i != _path)
        {
            if(i->weak_equal(_path))
            {
                m_History.insert(m_History.erase(i), move(_path));
            }
            else
            {
                m_IsRecording = true;
                m_History.resize(m_PlayingPosition + 1);
                m_History.emplace_back(move(_path));
            }
        }
    }
}

unsigned PanelHistory::Length() const
{
    return (unsigned)m_History.size();
}

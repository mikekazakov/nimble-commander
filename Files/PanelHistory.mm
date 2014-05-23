//
//  PanelHistory.mm
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "PanelHistory.h"

bool PanelHistory::IsBeyond() const
{
    assert(m_Position <= m_History.size());
    return m_Position == m_History.size();    
}

bool PanelHistory::IsBack() const
{
    return m_Position == 0;
}

void PanelHistory::MoveForth()
{
    if(m_Position < m_History.size())
        m_Position++;
}

void PanelHistory::MoveBack()
{
    if(m_Position > 0)
        m_Position--;
}

const VFSPathStack* PanelHistory::Current() const
{
    assert(m_Position <= m_History.size());
    if(m_Position == m_History.size())
        return nullptr;
    
    auto i = m_History.begin();
    std::advance(i, m_Position);
    return &*i;
}

void PanelHistory::Put(const VFSPathStack& _path)
{
    if(IsBeyond())
    {
        if(!m_History.empty() &&
           m_History.back() == _path)
            return;
        m_History.push_back(_path);
        m_Position++;
    }
    else
    {
        m_Position++;
        if(IsBeyond() || *Current() != _path)
        {
//            m_History.resize(m_Position+1);
//            m_History.back() = _path;
            m_History.emplace_back(_path);
        }
    }
}

void PanelHistory::Put(VFSPathStack&& _path)
{
    if(IsBeyond())
    {
        if(!m_History.empty() &&
           m_History.back() == _path)
            return;
        m_History.emplace_back(move(_path));
        m_Position++;
    }
    else
    {
        m_Position++;
        if(IsBeyond() || *Current() != _path)
        {
            //            m_History.resize(m_Position+1);
            //            m_History.back() = _path;
            m_History.emplace_back(move(_path));
        }
    }
}


unsigned PanelHistory::Length() const
{
    return (unsigned)m_History.size();
}

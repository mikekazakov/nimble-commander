//
//  PanelHistory.mm
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "PanelHistory.h"

PanelHistory::PanelHistory():
    m_Position(0)
{
    
    
}

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
        if(*Current() != _path)
        {
            m_History.resize(m_Position+1);
            m_History.back() = _path;
        }
        m_Position++;
    }
}

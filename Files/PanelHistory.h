//
//  PanelHistory.h
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import "VFS.h"

class PanelHistory
{
public:
    bool IsRecording() const;
    unsigned Length() const;
    
    bool CanMoveForth() const;
    void MoveForth();
    
    bool CanMoveBack() const;
    void MoveBack();
    
    
    void Put(VFSPathStack&& _path);
    const VFSPathStack* Current() const;
private:
    list<VFSPathStack>  m_History;
     // lesser the index - farther the history entry
     // most recent entry is at .size()-1
    unsigned            m_PlayingPosition = 0; // have meaningful value only when m_IsRecording==false
    bool                m_IsRecording = true;
    enum {              m_HistoryLength = 128 };
};

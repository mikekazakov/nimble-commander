//
//  PanelHistory.h
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#include "vfs/VFS.h"

class PanelHistory
{
public:
    bool IsRecording() const noexcept;
    unsigned Length() const noexcept;
    bool Empty() const noexcept;
    
    bool CanMoveForth() const noexcept;
    
    /**
     * Will throw if CanMoveForth() == false.
     */
    void MoveForth();
    
    bool CanMoveBack() const noexcept;
    
    /**
     * Will throw if CanMoveBack() == false.
     */
    void MoveBack();
    
    /**
     * Will turn History into "recording" state.
     * History was in playing state - will discard anything in front of current position.
     */
    void Put(VFSPathStack&& _path);
    
    /**
     * Will return nullptr if history is in "recording" state.
     */
    const VFSPathStack* Current() const;

    /**
     * Will put History in "playing" state and adjust playing position accordingly,
     * and return current history element
     */
    const VFSPathStack* RewindAt(size_t _indx);
    
    vector<reference_wrapper<const VFSPathStack>> All() const;
private:
    deque<VFSPathStack>  m_History;
     // lesser the index - farther the history entry
     // most recent entry is at .size()-1
    unsigned            m_PlayingPosition = 0; // have meaningful value only when m_IsRecording==false
    bool                m_IsRecording = true;
    enum {              m_HistoryLength = 128 };
};

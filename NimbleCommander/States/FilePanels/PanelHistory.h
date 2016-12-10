//
//  PanelHistory.h
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <VFS/VFS.h>
#include "../../Core/VFSInstanceManager.h"

/**
 * This class is not thread-safe.
 */
class PanelHistory
{
public:
    // currenly we store only vfs info and directory inside it
    struct Path
    {
        bool operator==(const Path&_rhs) const noexcept;
        bool operator!=(const Path&_rhs) const noexcept;
        VFSInstanceManager::Promise     vfs;
        string                          path;
    };
    
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
    void Put(VFSInstanceManager::Promise _vfs_promise, string _directory_path);
    
    /**
     * Will return nullptr if history is in "recording" state.
     */
    const Path* Current() const;

    /**
     * Will put History in "playing" state and adjust playing position accordingly,
     * and return current history element
     */
    const Path* RewindAt(size_t _indx);
    
    vector<reference_wrapper<const Path>> All() const;
private:
    deque<Path>         m_History;
     // lesser the index - farther the history entry
     // most recent entry is at .size()-1
    unsigned            m_PlayingPosition = 0; // have meaningful value only when m_IsRecording==false
    bool                m_IsRecording = true;
    enum {              m_HistoryLength = 128 };
};

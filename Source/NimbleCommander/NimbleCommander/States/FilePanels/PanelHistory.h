// Copyright (C) 2013-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS_fwd.h>
#include "ListingPromise.h"
#include <deque>

namespace nc::core {
class VFSInstanceManager;
}

namespace nc::panel {

/**
 * This class is not thread-safe.
 */
class History
{
public:
    using Path = ListingPromise;

    [[nodiscard]] bool IsRecording() const noexcept;
    [[nodiscard]] unsigned Length() const noexcept;
    [[nodiscard]] bool Empty() const noexcept;

    [[nodiscard]] bool CanMoveForth() const noexcept;

    /**
     * Will throw if CanMoveForth() == false.
     */
    void MoveForth();

    [[nodiscard]] bool CanMoveBack() const noexcept;

    /**
     * Will throw if CanMoveBack() == false.
     */
    void MoveBack();

    /**
     * Will turn History into "recording" state.
     * If history was in playing state - will discard anything in front of current position.
     */
    void Put(const VFSListing &_listing);

    /**
     * Will return nullptr if history is in "recording" state.
     */
    [[nodiscard]] const Path *CurrentPlaying() const;

    /**
     * Will put History in "playing" state and adjust playing position accordingly,
     * and return current history element
     */
    const Path *RewindAt(size_t _indx);

    /**
     * Returns the one most recently visited, either in a recording state or in a playing state.
     */
    [[nodiscard]] const Path *MostRecent() const;

    [[nodiscard]] std::vector<std::reference_wrapper<const Path>> All() const;

    [[nodiscard]] const std::string &LastNativeDirectoryVisited() const noexcept;

    void SetVFSInstanceManager(core::VFSInstanceManager &_mgr);

private:
    std::deque<Path> m_History;
    // lesser the index - farther the history entry
    // most recent entry is at .size()-1
    unsigned m_PlayingPosition = 0; // have meaningful value only when m_IsRecording==false
    bool m_IsRecording = true;
    std::string m_LastNativeDirectory;
    core::VFSInstanceManager *m_VFSMgr = nullptr;
    static constexpr size_t m_HistoryLength = 128;
};

} // namespace nc::panel

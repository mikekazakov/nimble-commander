// Copyright (C) 2018-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CursorBackup.h"
#include <Panel/PanelData.h>
#include <Panel/Log.h>

namespace nc::panel {

CursorBackup::CursorBackup(int _current_cursor_pos, const data::Model &_data) noexcept : m_Data(_data)
{
    Log::Trace("Saving cursor position: {}", _current_cursor_pos);
    if( _current_cursor_pos >= 0 ) {
        assert(_current_cursor_pos < _data.SortedEntriesCount());
        auto item = _data.EntryAtSortPosition(_current_cursor_pos);
        assert(item);
        m_OldCursorName = item.Filename();
        m_OldEntrySortKeys = _data.EntrySortKeysAtSortPosition(_current_cursor_pos);
        Log::Trace("Saved sort keys: {}", m_OldEntrySortKeys);
    }
}

int CursorBackup::RestoredCursorPosition() const noexcept
{
    Log::Trace("Restoring cursor position from the keys {}", m_OldEntrySortKeys);
    const int restored_pos = FindRestoredCursorPosition();
    Log::Trace("Restored cursor position: {}", restored_pos);
    return restored_pos;
}

int CursorBackup::FindRestoredCursorPosition() const noexcept
{
    if( m_OldCursorName.empty() ) {
        return m_Data.SortedEntriesCount() > 0 ? 0 : -1;
    }

    const auto new_cursor_raw_pos = m_Data.RawIndexForName(m_OldCursorName.c_str());
    if( new_cursor_raw_pos >= 0 ) {
        const auto new_cursor_sort_pos = m_Data.SortedIndexForRawIndex(new_cursor_raw_pos);
        if( new_cursor_sort_pos >= 0 )
            return new_cursor_sort_pos;
        else
            return m_Data.SortedDirectoryEntries().empty() ? -1 : 0;
    }
    else {
        const auto lower_bound_ind = m_Data.SortLowerBoundForEntrySortKeys(m_OldEntrySortKeys);
        if( lower_bound_ind >= 0 ) {
            return lower_bound_ind;
        }
        else {
            return m_Data.SortedEntriesCount() > 0 ? m_Data.SortedEntriesCount() - 1 : -1;
        }
    }
}

} // namespace nc::panel

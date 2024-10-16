// Copyright (C) 2018-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Panel/PanelDataExternalEntryKey.h>

namespace nc::panel {

namespace data {
class Model;
}

class CursorBackup
{
public:
    CursorBackup(int _current_cursor_pos, const data::Model &_data) noexcept;

    int RestoredCursorPosition() const noexcept;

private:
    int FindRestoredCursorPosition() const noexcept;

    const data::Model &m_Data;
    std::string m_OldCursorName; // reduntant? it's already in m_OldEntrySortKeys
    data::ExternalEntryKey m_OldEntrySortKeys;
};

} // namespace nc::panel

// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
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

    [[nodiscard]] int RestoredCursorPosition() const noexcept;

private:
    [[nodiscard]] int FindRestoredCursorPosition() const noexcept;

    const data::Model &m_Data;
    data::ExternalEntryKey m_Keys;
};

} // namespace nc::panel

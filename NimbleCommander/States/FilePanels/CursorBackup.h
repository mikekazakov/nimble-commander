// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelDataExternalEntryKey.h"

namespace nc::panel {

namespace data {
class Model;
}
    
class CursorBackup
{
public:
    CursorBackup(int _current_cursor_pos, const data::Model &_data);

    int RestoredCursorPosition() const;
private:
    int                         m_OldCursorPosition;
    const data::Model          &m_Data;
    std::string                 m_OldCursorName;
    data::ExternalEntryKey      m_OldEntrySortKeys;
};

}

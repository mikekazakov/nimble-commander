#pragma once

#include "PanelDataExternalEntryKey.h"

@class PanelView;

namespace nc::panel {

namespace data {
class Model;
}
    
class CursorBackup
{
public:
    CursorBackup(PanelView* _view, const data::Model &_data);
    void Restore() const;
    bool IsValid() const noexcept;
private:
    PanelView                  *m_View;
    const data::Model          &m_Data;
    string                      m_OldCursorName;
    data::ExternalEntryKey      m_OldEntrySortKeys;
};

}

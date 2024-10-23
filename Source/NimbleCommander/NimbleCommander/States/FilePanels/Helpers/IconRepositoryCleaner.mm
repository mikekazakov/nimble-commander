// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "IconRepositoryCleaner.h"
#include <Panel/PanelDataItemVolatileData.h>

#include <algorithm>

namespace nc::panel {

IconRepositoryCleaner::IconRepositoryCleaner(vfsicon::IconRepository &_repository, const data::Model &_data)
    : m_Repository(_repository), m_Data(_data)
{
}

void IconRepositoryCleaner::SweepUnusedSlots()
{
    const auto used_slots = m_Repository.AllSlots();
    auto still_in_use = std::vector<bool>(used_slots.size(), false);

    for( auto i = 0, e = m_Data.RawEntriesCount(); i < e; ++i ) {
        auto &vd = m_Data.VolatileDataAtRawPosition(i);
        if( vd.icon != vfsicon::IconRepository::InvalidKey ) {
            auto it = std::ranges::lower_bound(used_slots, vd.icon);
            if( it != std::end(used_slots) && *it == vd.icon )
                still_in_use[std::distance(std::begin(used_slots), it)] = true;
        }
    }

    for( int i = 0, e = static_cast<int>(used_slots.size()); i < e; ++i )
        if( !still_in_use[i] ) {
            m_Repository.Unregister(used_slots[i]);
        }
}

} // namespace nc::panel

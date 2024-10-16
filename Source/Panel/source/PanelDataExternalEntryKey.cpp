// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelDataExternalEntryKey.h"
#include "PanelDataItemVolatileData.h"

namespace nc::panel::data {

ExternalEntryKey::ExternalEntryKey() noexcept = default;

ExternalEntryKey::ExternalEntryKey(const VFSListingItem &_item, const ItemVolatileData &_item_vd) : ExternalEntryKey()
{
    name = _item.Filename();
    display_name.reset(_item.DisplayNameCF());
    extension = _item.HasExtension() ? _item.Extension() : "";
    size = _item_vd.size;
    mtime = _item.MTime();
    btime = _item.BTime();
    atime = _item.ATime();
    add_time = _item.HasAddTime() ? _item.AddTime() : -1;
    is_dir = _item.IsDir();
}

bool ExternalEntryKey::is_valid() const noexcept
{
    return !name.empty() && display_name;
}

} // namespace nc::panel::data

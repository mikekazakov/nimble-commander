// Copyright (C) 2016-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <boost/container/static_vector.hpp>

namespace nc::panel {

// these values are used in serializaition, don't change existing.
enum class PanelListViewColumns : signed char
{
    Empty = 0,
    Filename = 1,
    Extension = 7,
    Size = 2,
    DateCreated = 3,
    DateAdded = 4,
    DateModified = 5,
    DateAccessed = 6
};

struct PanelListViewColumnsLayout {
    struct Column {
        PanelListViewColumns kind; // = PanelListViewColumns::Empty;
        short width;               // = -1
        short max_width;           // = -1
        short min_width;           // = -1
        Column() noexcept;
        bool operator==(const Column &_rhs) const noexcept;
        bool operator!=(const Column &_rhs) const noexcept;
    };

    boost::container::static_vector<Column, 7> columns;
    unsigned char icon_scale; // = 1

    PanelListViewColumnsLayout() noexcept;
    bool operator==(const PanelListViewColumnsLayout &_rhs) const noexcept;
    bool operator!=(const PanelListViewColumnsLayout &_rhs) const noexcept;
};

} // namespace nc::panel

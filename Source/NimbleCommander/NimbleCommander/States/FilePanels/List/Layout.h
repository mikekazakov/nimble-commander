// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <boost/container/static_vector.hpp>

namespace nc::panel {

// these values are used in serialization, don't change the existing identifiers.
enum class PanelListViewColumns : signed char {
    Empty = 0,
    Filename = 1,
    Extension = 7,
    Size = 2,
    DateCreated = 3,
    DateAdded = 4,
    DateModified = 5,
    DateAccessed = 6,
    Tags = 8
};

struct PanelListViewColumnsLayout {
    struct Column {
        PanelListViewColumns kind = PanelListViewColumns::Empty;
        short width = -1;
        short max_width = -1;
        short min_width = -1;
        bool operator==(const Column &_rhs) const noexcept = default;
        bool operator!=(const Column &_rhs) const noexcept = default;
    };

    boost::container::static_vector<Column, 8> columns;
    unsigned char icon_scale = 1;

    bool operator==(const PanelListViewColumnsLayout &_rhs) const noexcept = default;
    bool operator!=(const PanelListViewColumnsLayout &_rhs) const noexcept = default;
};

} // namespace nc::panel

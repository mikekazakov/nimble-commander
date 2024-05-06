// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::term {

struct TranslateMaps {
    enum {
        USASCII = 0,
        UK = 1,
        Graph = 2
    };
};

extern const unsigned short g_TranslateMaps[3][256];

} // namespace nc::term

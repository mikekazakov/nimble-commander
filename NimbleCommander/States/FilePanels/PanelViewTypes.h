// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::panel {

enum class PanelViewFilenameTrimming : int8_t
{
    Heading     = 0,
    Middle      = 1,
    Trailing    = 2
};

namespace PanelViewHitTest {
    enum Options : int8_t {
        FullArea,
        FilenameArea,
        FilenameFact,
    };
};

}

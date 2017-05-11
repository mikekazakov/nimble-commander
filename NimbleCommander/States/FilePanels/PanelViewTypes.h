#pragma once

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

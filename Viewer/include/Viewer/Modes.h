#pragma once

enum class BigFileViewModes : int
{ // changing this values may cause stored history corruption
    Text = 0,
    Hex  = 1,
    Preview = 2
};


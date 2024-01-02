// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::viewer {

enum class ViewMode : int
{ // changing this values may cause stored history corruption
    Text = 0,
    Hex  = 1,
    Preview = 2
};

}

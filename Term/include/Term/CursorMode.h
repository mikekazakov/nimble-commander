// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stdint.h>

namespace nc::term {
    
enum class CursorMode : int8_t
{
    Block       = 0,
    Underline   = 1,
    VerticalBar = 2
};
    
using TermViewCursor = CursorMode;

}

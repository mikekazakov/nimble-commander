#pragma once

namespace nc::term {
    
enum class CursorMode : int8_t
{
    Block       = 0,
    Underline   = 1,
    VerticalBar = 2
};
    
using TermViewCursor = CursorMode;

}

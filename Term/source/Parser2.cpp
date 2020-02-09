#include "Parser2.h"
#include <type_traits>

static_assert( std::is_nothrow_default_constructible_v<nc::term::input::Command> );
static_assert( std::is_nothrow_move_constructible_v<nc::term::input::Command> );

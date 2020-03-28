// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Parser2.h"
#include <type_traits>

static_assert( std::is_nothrow_default_constructible_v<nc::term::input::Command> );
static_assert( std::is_nothrow_move_constructible_v<nc::term::input::Command> );

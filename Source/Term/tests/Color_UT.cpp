// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Screen.h>
#include "Tests.h"

using namespace nc::term;
#define PREFIX "nc::term::Color "

// 8-bit - generic mapping
static_assert(Color(255, 0, 0).c == 196);
static_assert(Color(0, 255, 0).c == 46);
static_assert(Color(0, 0, 255).c == 21);
static_assert(Color(255, 255, 0).c == 226);
static_assert(Color(255, 0, 255).c == 201);
static_assert(Color(0, 255, 255).c == 51);

// 8-bit - grayscale mapping
static_assert(Color(0, 0, 0).c == 232);
static_assert(Color(127, 127, 127).c == 243);
static_assert(Color(255, 255, 255).c == 255);

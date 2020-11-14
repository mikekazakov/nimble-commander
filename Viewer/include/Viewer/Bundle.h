// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#ifdef __OBJC__
#include <Cocoa/Cocoa.h>
#else
#include <Utility/NSCppDeclarations.h>
#endif

namespace nc::viewer {

NSBundle *Bundle() noexcept;

}

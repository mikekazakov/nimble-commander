// Copyright (C) 2019-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#ifdef __OBJC__
#include <Cocoa/Cocoa.h>
#else
#include <Utility/NSCppDeclarations.h>
#endif

#ifdef NSLocalizedString
#undef NSLocalizedString
#endif

namespace nc::viewer {

NSBundle *Bundle() noexcept;
NSString *NSLocalizedString(NSString *_key, const char *_comment) noexcept;

} // namespace nc::viewer

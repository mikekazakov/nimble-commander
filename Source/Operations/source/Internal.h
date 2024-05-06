// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#ifdef __OBJC__
#include <Cocoa/Cocoa.h>
#endif

namespace nc::ops {

#ifdef __OBJC__
NSBundle *Bundle() noexcept;

#undef NSLocalizedString
NSString *NSLocalizedString(NSString *_key, const char *_comment) noexcept;

#endif

} // namespace nc::ops

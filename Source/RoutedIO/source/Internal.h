// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#ifdef __OBJC__
#include <Cocoa/Cocoa.h>
#endif

#include <string>

namespace nc::routedio {

#ifdef __OBJC__
NSBundle *Bundle() noexcept;

#undef NSLocalizedString
NSString *NSLocalizedString(NSString *_key, const char *_comment) noexcept;

#endif

std::string MessageAuthAsAdmin() noexcept;
std::string MessageInstallHelperApp() noexcept;

} // namespace nc::routedio

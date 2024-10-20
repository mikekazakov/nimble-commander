// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string_view>

#ifdef __OBJC__
#include <Foundation/Foundation.h>
#endif

namespace nc::utility {

class VersionCompare
{
public:
    static int Compare(std::string_view _lhs, std::string_view _rhs) noexcept;
#ifdef __OBJC__
    static int Compare(NSString *_lhs, NSString *_rhs) noexcept;
#endif
};

} // namespace nc::utility

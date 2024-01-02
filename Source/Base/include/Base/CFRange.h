// Copyright (C) 2019-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <algorithm>

namespace nc::base {

constexpr inline bool operator==(const CFRange &_lhs, const CFRange &_rhs) noexcept
{
    return _lhs.location == _rhs.location && _lhs.length == _rhs.length;
}

constexpr inline bool operator!=(const CFRange &_lhs, const CFRange &_rhs) noexcept
{
    return !(_lhs == _rhs);
}

constexpr inline CFRange CFRangeIntersect(const CFRange &_lhs, const CFRange &_rhs) noexcept
{
    const auto start = std::max(_lhs.location, _rhs.location);
    const auto end = std::min(_lhs.location + _lhs.length, _rhs.location + _rhs.length);
    if( end <= start ) {
        return {0, -1};
    }
    else {
        return {start, end - start};
    }
}

constexpr inline bool CFRangeEmpty(const CFRange &_range) noexcept
{
    return _range.length <= 0;
}

constexpr inline bool CFRangeInside(const CFRange &_range, CFIndex _index) noexcept
{
    return _index >= _range.location && _index < _range.location + _range.length;
}

constexpr inline bool CFRangeInside(const CFRange &_outer, const CFRange &_inner) noexcept
{
    return CFRangeIntersect(_outer, _inner) == _inner;
}

constexpr inline CFIndex CFRangeMax(const CFRange &_range) noexcept
{
    return _range.location + _range.length;
}

} // namespace nc::base

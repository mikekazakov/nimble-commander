// Copyright (C) 2022-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <spdlog/fmt/fmt.h>
#include <CoreGraphics/CGGeometry.h>

template <>
struct fmt::formatter<CGSize> : fmt::formatter<std::string> {
    constexpr auto parse(fmt::format_parse_context &ctx) { return ctx.begin(); }

    template <typename FormatContext>
    auto format(const CGSize &sz, FormatContext &ctx) const
    {
        return fmt::format_to(ctx.out(), "({}, {})", sz.width, sz.height);
    }
};

template <>
struct fmt::formatter<CGPoint> : fmt::formatter<std::string> {
    constexpr auto parse(fmt::format_parse_context &ctx) { return ctx.begin(); }

    template <typename FormatContext>
    auto format(const CGPoint &pt, FormatContext &ctx) const
    {
        return fmt::format_to(ctx.out(), "({}, {})", pt.x, pt.y);
    }
};

template <>
struct fmt::formatter<CGRect> : fmt::formatter<std::string> {
    constexpr auto parse(fmt::format_parse_context &ctx) { return ctx.begin(); }

    template <typename FormatContext>
    auto format(const CGRect &rc, FormatContext &ctx) const
    {
        return fmt::format_to(ctx.out(), "({}, {}, {}, {})", rc.origin.x, rc.origin.y, rc.size.width, rc.size.height);
    }
};

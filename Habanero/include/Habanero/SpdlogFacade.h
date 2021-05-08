// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <spdlog/spdlog.h>
#include <spdlog/fmt/ostr.h>
#include <string_view>

#ifndef SPDLOC
#define SPDLOC                                                                                     \
    spdlog::source_loc { __FILE__, __LINE__, __FUNCTION__ }
#endif

namespace nc::base {

template <typename Impl>
class SpdlogFacade
{
public:
    template <typename... Args>
    static void Trace(spdlog::source_loc _loc, std::string_view _fmt, const Args &...args)
    {
        Impl::Get().log(_loc, spdlog::level::trace, _fmt, args...);
    }

    template <typename... Args>
    static void Debug(spdlog::source_loc _loc, std::string_view _fmt, const Args &...args)
    {
        Impl::Get().log(_loc, spdlog::level::debug, _fmt, args...);
    }

    template <typename... Args>
    static void Info(spdlog::source_loc _loc, std::string_view _fmt, const Args &...args)
    {
        Impl::Get().log(_loc, spdlog::level::info, _fmt, args...);
    }

    template <typename... Args>
    static void Warn(spdlog::source_loc _loc, std::string_view _fmt, const Args &...args)
    {
        Impl::Get().log(_loc, spdlog::level::warn, _fmt, args...);
    }

    template <typename... Args>
    static void Error(spdlog::source_loc _loc, std::string_view _fmt, const Args &...args)
    {
        Impl::Get().log(_loc, spdlog::level::err, _fmt, args...);
    }

    template <typename... Args>
    static void Critical(spdlog::source_loc _loc, std::string_view _fmt, const Args &...args)
    {
        Impl::Get().log(_loc, spdlog::level::critical, _fmt, args...);
    }
};

} // namespace nc::base

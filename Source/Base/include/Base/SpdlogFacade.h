// Copyright (C) 2021-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <spdlog/spdlog.h>
#include <spdlog/fmt/ostr.h>
#include <string>
#include <string_view>
#include <source_location>
#include "SpdlogFormatters.h"

namespace nc::base {

class SpdLogger
{
public:
    SpdLogger(std::string_view _name);

    spdlog::logger &Get() noexcept;
    void Set(std::shared_ptr<spdlog::logger> _logger) noexcept;
    const std::string &Name() noexcept;

private:
    std::string m_Name;
    std::shared_ptr<spdlog::logger> m_Logger;
    std::vector<std::shared_ptr<spdlog::logger>> m_OldLoggers;
};

struct SpdlogLocAndFmt {
    template <class String>
    constexpr SpdlogLocAndFmt(const String &_fmt, const std::source_location &_loc = std::source_location::current())
        : fmt{_fmt}, loc{_loc.file_name(), static_cast<int>(_loc.line()), _loc.function_name()}
    {
    }

    std::string_view fmt;
    spdlog::source_loc loc;
};

template <typename Impl>
class SpdlogFacade
{
public:
    SpdlogFacade() = delete;

    static SpdLogger &Logger() noexcept { return Impl::m_Logger; }

    static const std::string &Name() noexcept { return Impl::m_Logger.Name(); }

    static spdlog::level::level_enum Level() noexcept { return Get().level(); }

    static spdlog::logger &Get() noexcept { return Impl::m_Logger.Get(); }

    static void Set(std::shared_ptr<spdlog::logger> _logger) noexcept { Impl::m_Logger.Set(_logger); }

    template <typename... Args>
    static void Trace(SpdlogLocAndFmt _locfmt, const Args &...args)
    {
        Get().log(_locfmt.loc, spdlog::level::trace, fmt::runtime(_locfmt.fmt), args...);
    }

    template <typename... Args>
    static void Debug(SpdlogLocAndFmt _locfmt, const Args &...args)
    {
        Get().log(_locfmt.loc, spdlog::level::debug, fmt::runtime(_locfmt.fmt), args...);
    }

    template <typename... Args>
    static void Info(SpdlogLocAndFmt _locfmt, const Args &...args)
    {
        Get().log(_locfmt.loc, spdlog::level::info, fmt::runtime(_locfmt.fmt), args...);
    }

    template <typename... Args>
    static void Warn(SpdlogLocAndFmt _locfmt, const Args &...args)
    {
        Get().log(_locfmt.loc, spdlog::level::warn, fmt::runtime(_locfmt.fmt), args...);
    }

    template <typename... Args>
    static void Error(SpdlogLocAndFmt _locfmt, const Args &...args)
    {
        Get().log(_locfmt.loc, spdlog::level::err, fmt::runtime(_locfmt.fmt), args...);
    }

    template <typename... Args>
    static void Critical(SpdlogLocAndFmt _locfmt, const Args &...args)
    {
        Get().log(_locfmt.loc, spdlog::level::critical, fmt::runtime(_locfmt.fmt), args...);
    }
};

} // namespace nc::base

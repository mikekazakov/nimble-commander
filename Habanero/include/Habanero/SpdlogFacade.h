// Copyright (C) 2021-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <spdlog/spdlog.h>
#include <spdlog/fmt/ostr.h>
#include <string>
#include <string_view>
#include "SpdlogFormatters.h"

#ifndef SPDLOC
#define SPDLOC                                                                                                         \
    spdlog::source_loc { __FILE__, __LINE__, __FUNCTION__ }
#endif

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
    static void Trace(spdlog::source_loc _loc, std::string_view _fmt, const Args &...args)
    {
        Get().log(_loc, spdlog::level::trace, _fmt, args...);
    }

    template <typename... Args>
    static void Debug(spdlog::source_loc _loc, std::string_view _fmt, const Args &...args)
    {
        Get().log(_loc, spdlog::level::debug, _fmt, args...);
    }

    template <typename... Args>
    static void Info(spdlog::source_loc _loc, std::string_view _fmt, const Args &...args)
    {
        Get().log(_loc, spdlog::level::info, _fmt, args...);
    }

    template <typename... Args>
    static void Warn(spdlog::source_loc _loc, std::string_view _fmt, const Args &...args)
    {
        Get().log(_loc, spdlog::level::warn, _fmt, args...);
    }

    template <typename... Args>
    static void Error(spdlog::source_loc _loc, std::string_view _fmt, const Args &...args)
    {
        Get().log(_loc, spdlog::level::err, _fmt, args...);
    }

    template <typename... Args>
    static void Critical(spdlog::source_loc _loc, std::string_view _fmt, const Args &...args)
    {
        Get().log(_loc, spdlog::level::critical, _fmt, args...);
    }
};

} // namespace nc::base

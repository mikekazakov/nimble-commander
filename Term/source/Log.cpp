// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Log.h"
#include <spdlog/sinks/null_sink.h>
#include <mutex>
#include <cassert>

namespace nc::term {

[[clang::no_destroy]] static std::shared_ptr<spdlog::logger> g_Logger;

const std::string &Log::Name() noexcept
{
    [[clang::no_destroy]] static const std::string name("term");
    return name;
}

spdlog::logger &Log::Get() noexcept
{
    static std::once_flag flag;
    std::call_once(flag, [] {
        if( g_Logger == nullptr ) {
            g_Logger = spdlog::null_logger_mt(Name());
        }
    });

    assert(g_Logger);
    return *g_Logger;
}

void Log::Set(std::shared_ptr<spdlog::logger> _logger) noexcept
{
    assert(_logger);
    if( g_Logger ) {
        // deliberately leak the existing logger
        new std::shared_ptr<spdlog::logger>(g_Logger);
    }

    // now update our logger. that's really not thread-safe
    g_Logger = std::move(_logger);
}

} // namespace nc::term

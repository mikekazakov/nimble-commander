// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SpdlogFacade.h"
#include <spdlog/sinks/null_sink.h>
#include <cassert>

namespace nc::base {

SpdLogger::SpdLogger(std::string_view _name) : m_Name(_name)
{
    assert(_name.empty() == false);
    m_Logger = spdlog::null_logger_mt(m_Name);
}

const std::string &SpdLogger::Name() noexcept
{
    assert(m_Name.empty() == false);
    return m_Name;
}

spdlog::logger &SpdLogger::Get() noexcept
{
    assert(m_Logger);
    return *m_Logger;
}

void SpdLogger::Set(std::shared_ptr<spdlog::logger> _logger) noexcept
{
    assert(_logger);
    m_OldLoggers.emplace_back(m_Logger); // don't release the existing logger

    // now update our logger. that's really not thread-safe
    m_Logger = std::move(_logger);
}

} // namespace nc::base

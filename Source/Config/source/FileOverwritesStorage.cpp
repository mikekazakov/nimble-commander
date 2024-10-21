// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FileOverwritesStorage.h"
#include "Log.h"
#include <sys/stat.h>
#include <unistd.h>
#include <fstream>
#include <Base/CommonPaths.h>
#include <Base/WriteAtomically.h>
#include <Utility/FSEventsDirUpdate.h>
#include <filesystem>
#include <fmt/std.h>

namespace nc::config {

using utility::FSEventsDirUpdate;
static std::optional<std::string> Load(const std::string &_filepath);
static time_t ModificationTime(const std::string &_filepath);

FileOverwritesStorage::FileOverwritesStorage(const std::filesystem::path &_file_path) : m_Path(_file_path)
{
    Log::Trace("Created storage with path: {}", _file_path);
    auto parent_path = _file_path.parent_path();
    Log::Trace("Setting observation for directory: {}", parent_path);
    m_DirObservationTicket =
        FSEventsDirUpdate::Instance().AddWatchPath(parent_path.c_str(), [this] { OverwritesDirChanged(); });
}

FileOverwritesStorage::~FileOverwritesStorage()
{
    FSEventsDirUpdate::Instance().RemoveWatchPathWithTicket(m_DirObservationTicket);
    Log::Trace("Instance destroyed");
}

std::optional<std::string> FileOverwritesStorage::Read() const
{
    auto file_contents = Load(m_Path);
    if( file_contents ) {
        Log::Info("Successfully read overwrites from {}", m_Path);
        m_OverwritesTime = ModificationTime(m_Path);
    }
    else {
        Log::Info("Failed to read overwrites from {}", m_Path);
    }
    return file_contents;
}

void FileOverwritesStorage::Write(std::string_view _overwrites_json)
{
    const auto bytes = std::span<const std::byte>(reinterpret_cast<const std::byte *>(_overwrites_json.data()),
                                                  _overwrites_json.length());
    if( base::WriteAtomically(m_Path, bytes) ) {
        Log::Info("Successfully written overwrites to {}", m_Path);
        m_OverwritesTime = ModificationTime(m_Path);
    }
    else {
        Log::Error("Failed to write overwrites to {}", m_Path);
    }
}

void FileOverwritesStorage::SetExternalChangeCallback(std::function<void()> _callback)
{
    m_OnChange = std::move(_callback);
}

void FileOverwritesStorage::OverwritesDirChanged()
{
    Log::Info("Overwrites directory was changed");
    const auto current_time = ModificationTime(m_Path);
    if( current_time != m_OverwritesTime ) {
        m_OverwritesTime = current_time;
        if( m_OnChange )
            m_OnChange();
    }
}

static std::optional<std::string> Load(const std::string &_filepath)
{
    std::ifstream in(_filepath, std::ios::in | std::ios::binary);
    if( !in )
        return std::nullopt;

    std::string contents;
    in.seekg(0, std::ios::end);
    const auto length = in.tellg();
    contents.resize(static_cast<size_t>(length));
    in.seekg(0, std::ios::beg);
    in.read(contents.data(), length);
    in.close();
    return contents;
}

static time_t ModificationTime(const std::string &_filepath)
{
    struct stat st;
    if( stat(_filepath.c_str(), &st) == 0 )
        return st.st_mtime;
    return 0;
}

} // namespace nc::config

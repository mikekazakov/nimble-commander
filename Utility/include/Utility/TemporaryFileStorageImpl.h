// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "TemporaryFileStorage.h"
#include <mutex>
#include <vector>

namespace nc::utility {
    
class TemporaryFileStorageImpl : public TemporaryFileStorage
{
public:
    TemporaryFileStorageImpl(std::string_view _base_directory,
                             std::string_view _sub_directories_prefix);
    
    std::optional<std::string> MakeDirectory( std::string_view _filename = {} ) override;
    std::optional<OpenedFile> OpenFile( std::string_view _filename = {} ) override;
    
private:
    std::optional<std::string> SpawnNewTempDir() const; // returns a path with a trailing slash
    std::optional<std::string> FindSuitableExistingTempDir( std::string_view _for_filename );
    std::optional<std::string> FindTempDir( std::string_view _for_filename );
    
    std::string m_BaseDirectory;
    std::string m_SubDirectoriesPrefix;
    std::mutex m_TempDirectoriesLock;
    std::vector<std::string> m_TempDirectories;
};

}


// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "OverwritesStorage.h"
#include <string_view>
#include <time.h>

namespace nc::config {

// NB! this class is not properly synchronized yet.    
class FileOverwritesStorage : public OverwritesStorage
{
public:
    FileOverwritesStorage(std::string_view _file_path);
    FileOverwritesStorage(const FileOverwritesStorage&) = delete;
    ~FileOverwritesStorage();

    std::optional<std::string> Read() const override;
    void Write(std::string_view _overwrites_json) override;
    void SetExternalChangeCallback( std::function<void()> _callback ) override;

private:
    void operator=(const FileOverwritesStorage&) = delete;
    void OverwritesDirChanged();
    
    std::string m_Path;    
    mutable std::atomic<time_t> m_OverwritesTime = {0};
    uint64_t m_DirObservationTicket = {0};
    std::function<void()> m_OnChange;
};

}

// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Modes.h"

#include <Config/Config.h>
#include <Utility/Encodings.h>
#include <Base/spinlock.h>
#include <deque>
#include <vector>
#include <mutex>
#include <CoreFoundation/CoreFoundation.h>

namespace nc::viewer {

class History
{
public:
    struct SaveOptions {
        bool encoding : 1 = false;
        bool mode : 1 = false;
        bool position : 1 = false;
        bool wrapping : 1 = false;
        bool selection : 1 = false;
        bool language : 1 = false;
    };

    struct Entry {
        std::string path; // works as a access key
        uint64_t position = 0;
        bool wrapping = false;
        ViewMode view_mode = ViewMode::Text;
        utility::Encoding encoding = utility::Encoding::ENCODING_INVALID;
        CFRange selection = {-1, 0};
        std::optional<std::string> language;
    };

    History(nc::config::Config &_global_config, nc::config::Config &_state_config, const char *_config_path);

    /**
     * Thread-safe.
     */
    void AddEntry(Entry _entry);

    /**
     * Thread-safe.
     */
    std::optional<Entry> EntryByPath(const std::string &_path) const;

    /**
     * Thread-safe.
     */
    void ClearHistory();

    /**
     * Thread-safe.
     */
    SaveOptions Options() const;

    /**
     * Returns true if any of Options() flags are on.
     * Thread-safe.
     */
    bool Enabled() const;

    void SaveToStateConfig() const;

private:
    void LoadSaveOptions();
    void LoadFromStateConfig();

    std::deque<Entry> m_History;
    mutable std::mutex m_HistoryLock;

    std::vector<nc::config::Token> m_ConfigObservations;
    SaveOptions m_Options;
    size_t m_Limit;
    nc::config::Config &m_GlobalConfig;
    nc::config::Config &m_StateConfig;
    std::string m_StateConfigPath;
};

} // namespace nc::viewer

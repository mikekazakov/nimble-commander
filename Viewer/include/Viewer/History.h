// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Modes.h"

#include <Config/Config.h>
#include <Habanero/spinlock.h>
#include <deque>
#include <vector>
#include <CoreFoundation/CoreFoundation.h>

namespace nc::viewer {

class History
{
public:
    struct SaveOptions
    {
        bool encoding = false;
        bool mode = false;
        bool position = false;
        bool wrapping = false;
        bool selection = false;
    };
    
    struct Entry
    {
        std::string         path; // works as a access key
        uint64_t            position = 0;
        bool                wrapping = false;
        ViewMode            view_mode = ViewMode::Text;
        int                 encoding = 0;
        CFRange             selection = {-1, 0};
    };
    
    History(nc::config::Config &_global_config,
            nc::config::Config &_state_config,
            const char *_config_path );

    /**
     * Thread-safe.
     */
    void AddEntry( Entry _entry );

    /**
     * Thread-safe.
     */
    std::optional<Entry> EntryByPath( const std::string &_path ) const;

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
    
    std::deque<Entry>               m_History;
    mutable spinlock                m_HistoryLock;

    std::vector<nc::config::Token>  m_ConfigObservations;
    SaveOptions                     m_Options;
    size_t                          m_Limit;
    nc::config::Config&             m_GlobalConfig;
    nc::config::Config&             m_StateConfig;
    std::string                     m_StateConfigPath;
};

}

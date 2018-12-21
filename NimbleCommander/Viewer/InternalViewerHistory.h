// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Config/Config.h>
#include "BigFileView.h"
#include <Habanero/spinlock.h>
#include <deque>

class InternalViewerHistory
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
        BigFileViewModes    view_mode = BigFileViewModes::Text;
        int                 encoding = 0;
        CFRange             selection = {-1, 0};
    };
    
    InternalViewerHistory( nc::config::Config &_state_config, const char *_config_path );
    
    static InternalViewerHistory& Instance();

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
    
    
private:
    void LoadSaveOptions();
    void LoadFromStateConfig();
    void SaveToStateConfig() const;
    
    std::deque<Entry>                           m_History;
    mutable spinlock                            m_HistoryLock;

    std::vector<nc::config::Token>              m_ConfigObservations;
    SaveOptions                                 m_Options;
    const size_t                                m_Limit;
    nc::config::Config&                         m_StateConfig;
    const char *const                           m_StateConfigPath;
};

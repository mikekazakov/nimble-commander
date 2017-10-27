// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Bootstrap/Config.h"
#include "BigFileView.h"

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
        string              path; // works as a access key
        uint64_t            position = 0;
        bool                wrapping = false;
        BigFileViewModes    view_mode = BigFileViewModes::Text;
        int                 encoding = 0;
        CFRange             selection = {-1, 0};
    };
    
    InternalViewerHistory( GenericConfig &_state_config, const char *_config_path );
    
    static InternalViewerHistory& Instance();

    /**
     * Thread-safe.
     */
    void AddEntry( Entry _entry );

    /**
     * Thread-safe.
     */
    optional<Entry> EntryByPath( const string &_path ) const;

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
    
    deque<Entry>                                m_History;
    mutable spinlock                            m_HistoryLock;

    vector<GenericConfig::ObservationTicket>    m_ConfigObservations;
    SaveOptions                                 m_Options;
    const size_t                                m_Limit;
    GenericConfig&                              m_StateConfig;
    const char *const                           m_StateConfigPath;
};

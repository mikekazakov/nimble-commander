// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

// STA - main thread usage only
class PanelViewFooterVolumeInfoFetcher
{
public:
    PanelViewFooterVolumeInfoFetcher();
    ~PanelViewFooterVolumeInfoFetcher();
    
    void SetCallback( function<void(const VFSStatFS&)> _callback );
    void SetTarget( const VFSListingPtr &_listing );
    const VFSStatFS& Current() const;
    
    bool IsActive() const;
    void PauseUpdates();
    void ResumeUpdates();

private:
    VFSHostWeakPtr m_Host;
    string         m_Path;
    VFSStatFS m_Current;
    function<void(const VFSStatFS&)> m_Callback;
    bool      m_Active = false;

    void Accept( const VFSStatFS &_stat );
    PanelViewFooterVolumeInfoFetcher( const PanelViewFooterVolumeInfoFetcher &_r ) = delete;
    void operator=( const PanelViewFooterVolumeInfoFetcher &_r ) = delete;
    friend struct PanelViewFooterVolumeInfoFetcherInternals;
};

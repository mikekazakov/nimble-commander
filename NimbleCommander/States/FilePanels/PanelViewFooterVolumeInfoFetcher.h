// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

namespace nc::panel {

// STA - main thread usage only
class FooterVolumeInfoFetcher
{
public:
    FooterVolumeInfoFetcher();
    ~FooterVolumeInfoFetcher();
    
    void SetCallback( std::function<void(const VFSStatFS&)> _callback );
    void SetTarget( const VFSListingPtr &_listing );
    const VFSStatFS& Current() const;
    
    bool IsActive() const;
    void PauseUpdates();
    void ResumeUpdates();

private:
    VFSHostWeakPtr m_Host;
    std::string    m_Path;
    VFSStatFS m_Current;
    std::function<void(const VFSStatFS&)> m_Callback;
    bool      m_Active = false;

    void Accept( const VFSStatFS &_stat );
    FooterVolumeInfoFetcher( const FooterVolumeInfoFetcher &_r ) = delete;
    void operator=( const FooterVolumeInfoFetcher &_r ) = delete;
    friend struct PanelViewFooterVolumeInfoFetcherInternals;
};

}

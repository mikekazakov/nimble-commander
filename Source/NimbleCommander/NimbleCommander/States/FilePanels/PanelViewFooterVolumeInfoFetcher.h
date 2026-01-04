// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

namespace nc::panel {

// STA - main thread usage only
class FooterVolumeInfoFetcher
{
public:
    FooterVolumeInfoFetcher();
    FooterVolumeInfoFetcher(const FooterVolumeInfoFetcher &_r) = delete;
    ~FooterVolumeInfoFetcher();
    void operator=(const FooterVolumeInfoFetcher &_r) = delete;

    void SetCallback(std::function<void(const VFSStatFS &)> _callback);
    void SetTarget(const VFSListingPtr &_listing);
    [[nodiscard]] const VFSStatFS &Current() const;

    [[nodiscard]] bool IsActive() const;
    void PauseUpdates();
    void ResumeUpdates();

private:
    VFSHostWeakPtr m_Host;
    std::string m_Path;
    VFSStatFS m_Current;
    std::function<void(const VFSStatFS &)> m_Callback;
    bool m_Active = false;

    void Accept(const VFSStatFS &_stat);
    friend struct PanelViewFooterVolumeInfoFetcherInternals;
};

} // namespace nc::panel

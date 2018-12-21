// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

namespace nc::core {

class Dock
{
public:
    Dock();
    ~Dock();
    
    double Progress() const noexcept;
    void SetProgress(double _value);
    
    void SetAdminBadge( bool _value );
    bool IsAdminBadgeSet() const noexcept;

    void SetUnregisteredBadge( bool _value );
    bool IsAUnregisteredBadgeSet() const noexcept;
    
private:
    Dock(const Dock&) = delete;
    void operator=(const Dock&) = delete;
    void UpdateBadge();
    
    double              m_Progress;
    bool                m_Admin;
    bool                m_Unregistered;
    NSDockTile          *m_Tile;
    NSImageView         *m_ContentView;
    NSProgressIndicator *m_Indicator;
    NSView              *m_UnregBadge;
};

}

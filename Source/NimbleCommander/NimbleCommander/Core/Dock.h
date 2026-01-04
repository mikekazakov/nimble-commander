// Copyright (C) 2017-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

namespace nc::core {

class Dock
{
public:
    Dock();
    Dock(const Dock &) = delete;
    ~Dock();

    void operator=(const Dock &) = delete;

    [[nodiscard]] double Progress() const noexcept;
    void SetProgress(double _value);

    void SetAdminBadge(bool _value);
    [[nodiscard]] bool IsAdminBadgeSet() const noexcept;

    void SetBaseIcon(NSImage *_icon);

private:
    void UpdateBadge();

    double m_Progress{-1.};
    bool m_Admin{false};
    NSDockTile *m_Tile;
    NSImageView *m_ContentView;
    NSProgressIndicator *m_Indicator;
};

} // namespace nc::core

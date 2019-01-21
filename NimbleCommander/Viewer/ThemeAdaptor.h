// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Viewer/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>

namespace nc::viewer {
    
class ThemeAdaptor : public Theme
{
public:
    ThemeAdaptor(ThemesManager &_themes_mgr);
    NSFont  *Font() const override;
    NSColor *OverlayColor() const override;
    NSColor *TextColor() const override;
    NSColor *ViewerSelectionColor() const override;
    NSColor *ViewerBackgroundColor() const override;
    void ObserveChanges( std::function<void()> _callback ) override;
private:
    const ::Theme &CurrentTheme() const;
    ThemesManager &m_ThemesManager;
    ThemesManager::ObservationTicket m_ThemeObservation;
};
    
}

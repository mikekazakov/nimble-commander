// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelViewHeaderTheme.h"
#include <NimbleCommander/Core/Theming/ThemesManager.h>

namespace nc::panel {

class HeaderThemeImpl final : public HeaderTheme 
{
public:
    HeaderThemeImpl(ThemesManager &_themes_mgr);
    NSFont *Font() const override;
    NSColor *TextColor() const override;
    NSColor *ActiveTextColor() const override;
    NSColor *ActiveBackgroundColor() const override;
    NSColor *InactiveBackgroundColor() const override;
    NSColor *SeparatorColor() const override;
    void ObserveChanges( std::function<void()> _callback ) override;   
private:
    ThemesManager &m_ThemesManager;    
    ThemesManager::ObservationTicket m_ThemeObservation;
};

}

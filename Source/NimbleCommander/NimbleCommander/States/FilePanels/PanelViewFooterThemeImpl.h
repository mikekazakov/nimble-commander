// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelViewFooterTheme.h"
#include <NimbleCommander/Core/Theming/ThemesManager.h>

namespace nc::panel {

class FooterThemeImpl final : public FooterTheme
{
public:
    FooterThemeImpl(ThemesManager &_themes_mgr);
    virtual ~FooterThemeImpl();
    NSFont  *Font() const override;
    NSColor *TextColor() const override;
    NSColor *ActiveTextColor() const override;
    NSColor *SeparatorsColor() const override;
    NSColor *ActiveBackgroundColor() const override;
    NSColor *InactiveBackgroundColor() const override;
    void ObserveChanges( std::function<void()> _callback ) override;
private:
    ThemesManager &m_ThemesManager;    
    ThemesManager::ObservationTicket m_ThemeObservation;
};
    
}

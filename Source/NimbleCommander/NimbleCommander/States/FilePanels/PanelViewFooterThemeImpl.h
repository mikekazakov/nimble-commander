// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelViewFooterTheme.h"
#include <NimbleCommander/Core/Theming/ThemesManager.h>

namespace nc::panel {

class FooterThemeImpl final : public FooterTheme
{
public:
    FooterThemeImpl(ThemesManager &_themes_mgr);
    ~FooterThemeImpl() override;
    [[nodiscard]] NSFont *Font() const override;
    [[nodiscard]] NSColor *TextColor() const override;
    [[nodiscard]] NSColor *ActiveTextColor() const override;
    [[nodiscard]] NSColor *SeparatorsColor() const override;
    [[nodiscard]] NSColor *ActiveBackgroundColor() const override;
    [[nodiscard]] NSColor *InactiveBackgroundColor() const override;
    void ObserveChanges(std::function<void()> _callback) override;

private:
    ThemesManager &m_ThemesManager;
    ThemesManager::ObservationTicket m_ThemeObservation;
};

} // namespace nc::panel

// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelViewHeaderTheme.h"
#include <NimbleCommander/Core/Theming/ThemesManager.h>

namespace nc::panel {

class HeaderThemeImpl final : public HeaderTheme
{
public:
    HeaderThemeImpl(ThemesManager &_themes_mgr);
    [[nodiscard]] NSFont *Font() const override;
    [[nodiscard]] NSColor *TextColor() const override;
    [[nodiscard]] NSColor *ActiveTextColor() const override;
    [[nodiscard]] NSColor *ActiveBackgroundColor() const override;
    [[nodiscard]] NSColor *InactiveBackgroundColor() const override;
    [[nodiscard]] NSColor *SeparatorColor() const override;
    void ObserveChanges(std::function<void()> _callback) override;

private:
    ThemesManager &m_ThemesManager;
    ThemesManager::ObservationTicket m_ThemeObservation;
};

} // namespace nc::panel

// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelViewHeaderThemeImpl.h"
#include <NimbleCommander/Core/Theming/Theme.h>

namespace nc::panel {

HeaderThemeImpl::HeaderThemeImpl(ThemesManager &_themes_mgr) : m_ThemesManager(_themes_mgr)
{
}

NSFont *HeaderThemeImpl::Font() const
{
    return m_ThemesManager.SelectedTheme().FilePanelsHeaderFont();
}

NSColor *HeaderThemeImpl::TextColor() const
{
    return m_ThemesManager.SelectedTheme().FilePanelsHeaderTextColor();
}

NSColor *HeaderThemeImpl::ActiveTextColor() const
{
    return m_ThemesManager.SelectedTheme().FilePanelsHeaderActiveTextColor();
}

NSColor *HeaderThemeImpl::ActiveBackgroundColor() const
{
    return m_ThemesManager.SelectedTheme().FilePanelsHeaderActiveBackgroundColor();
}

NSColor *HeaderThemeImpl::InactiveBackgroundColor() const
{
    return m_ThemesManager.SelectedTheme().FilePanelsHeaderInactiveBackgroundColor();
}

NSColor *HeaderThemeImpl::SeparatorColor() const
{
    return m_ThemesManager.SelectedTheme().FilePanelsHeaderSeparatorColor();
}

NSColor *HeaderThemeImpl::PathSeparatorColor() const
{
    return m_ThemesManager.SelectedTheme().FilePanelsHeaderPathSeparatorColor();
}

NSColor *HeaderThemeImpl::PathAccentColor() const
{
    return m_ThemesManager.SelectedTheme().FilePanelsHeaderPathAccentColor();
}

unsigned HeaderThemeImpl::PathHoverPadX() const
{
    return m_ThemesManager.SelectedTheme().FilePanelsHeaderPathHoverPadX();
}

unsigned HeaderThemeImpl::PathHoverPadYTop() const
{
    return m_ThemesManager.SelectedTheme().FilePanelsHeaderPathHoverPadYTop();
}

unsigned HeaderThemeImpl::PathHoverPadYBottom() const
{
    return m_ThemesManager.SelectedTheme().FilePanelsHeaderPathHoverPadYBottom();
}

unsigned HeaderThemeImpl::PathHoverCornerRadius() const
{
    return m_ThemesManager.SelectedTheme().FilePanelsHeaderPathHoverCornerRadius();
}

void HeaderThemeImpl::ObserveChanges(std::function<void()> _callback)
{
    const auto filter = ThemesManager::Notifications::FilePanelsHeader;
    m_ThemeObservation = m_ThemesManager.ObserveChanges(filter, std::move(_callback));
}

} // namespace nc::panel

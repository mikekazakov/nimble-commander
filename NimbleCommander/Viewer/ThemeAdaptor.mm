// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ThemeAdaptor.h"
#include <NimbleCommander/Core/Theming/Theme.h>

namespace nc::viewer {

ThemeAdaptor::ThemeAdaptor(ThemesManager &_themes_mgr):
    m_ThemesManager{_themes_mgr}
{
}

NSFont *ThemeAdaptor::Font() const
{
    return CurrentTheme().ViewerFont();
}
    
NSColor *ThemeAdaptor::OverlayColor() const
{
    return CurrentTheme().ViewerOverlayColor();
}
    
NSColor *ThemeAdaptor::TextColor() const
{
    return CurrentTheme().ViewerTextColor();
}
    
NSColor *ThemeAdaptor::ViewerSelectionColor() const
{
    return CurrentTheme().ViewerSelectionColor();
}
    
NSColor *ThemeAdaptor::ViewerBackgroundColor() const
{
    return CurrentTheme().ViewerBackgroundColor();
}

void ThemeAdaptor::ObserveChanges( std::function<void()> _callback )
{
    const auto filter = ThemesManager::Notifications::Viewer;
    m_ThemeObservation = m_ThemesManager.ObserveChanges(filter, std::move(_callback) );
}

const ::Theme &ThemeAdaptor::CurrentTheme() const
{
    return m_ThemesManager.SelectedTheme();
}

}

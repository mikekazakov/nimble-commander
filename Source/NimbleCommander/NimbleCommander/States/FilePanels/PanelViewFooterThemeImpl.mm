// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.

#include "PanelViewFooterThemeImpl.h"
#include <NimbleCommander/Core/Theming/Theme.h>

namespace nc::panel {

FooterThemeImpl::FooterThemeImpl(ThemesManager &_themes_mgr):
    m_ThemesManager(_themes_mgr)
{
}

FooterThemeImpl::~FooterThemeImpl()
{        
}
    
NSFont *FooterThemeImpl::Font() const
{
    return m_ThemesManager.SelectedTheme().FilePanelsFooterFont();
}
    
NSColor *FooterThemeImpl::TextColor() const
{   
    return m_ThemesManager.SelectedTheme().FilePanelsFooterTextColor();
}
    
NSColor *FooterThemeImpl::ActiveTextColor() const
{   
    return m_ThemesManager.SelectedTheme().FilePanelsFooterActiveTextColor();
}
    
NSColor *FooterThemeImpl::SeparatorsColor() const
{   
    return m_ThemesManager.SelectedTheme().FilePanelsFooterSeparatorsColor();
}
    
NSColor *FooterThemeImpl::ActiveBackgroundColor() const
{   
    return m_ThemesManager.SelectedTheme().FilePanelsFooterActiveBackgroundColor();
}
    
NSColor *FooterThemeImpl::InactiveBackgroundColor() const
{   
    return m_ThemesManager.SelectedTheme().FilePanelsFooterInactiveBackgroundColor();
}
    
void FooterThemeImpl::ObserveChanges( std::function<void()> _callback )
{        
    const auto filter = ThemesManager::Notifications::FilePanelsFooter;
    m_ThemeObservation = m_ThemesManager.ObserveChanges(filter, std::move(_callback) );    
}

}

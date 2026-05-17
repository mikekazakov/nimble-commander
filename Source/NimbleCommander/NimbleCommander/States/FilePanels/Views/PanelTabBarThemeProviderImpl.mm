// Copyright (C) 2014-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelTabBarThemeProviderImpl.h"
#include <Panel/UI/PanelTabBarView.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>

@implementation NCPanelTabBarThemeProviderImpl {
    nc::ThemesManager *m_ThemesManager;
    nc::ThemesManager::ObservationTicket m_ThemeChangesObservation;
}

- (instancetype)initWithThemesManager:(nc::ThemesManager &)_themes_mgr
{
    self = [super init];
    if( self ) {
        m_ThemesManager = &_themes_mgr;
    }
    return self;
}

- (NSFont *)font
{
    return nc::CurrentTheme().FilePanelsTabsFont();
}

- (NSColor *)textColor
{
    return nc::CurrentTheme().FilePanelsTabsTextColor();
}

- (NSColor *)selectedKeyWndActiveBackgroundColor
{
    return nc::CurrentTheme().FilePanelsTabsSelectedKeyWndActiveBackgroundColor();
}

- (NSColor *)selectedKeyWndInactiveBackgroundColor
{
    return nc::CurrentTheme().FilePanelsTabsSelectedKeyWndInactiveBackgroundColor();
}

- (NSColor *)selectedNotKeyWndBackgroundColor
{
    return nc::CurrentTheme().FilePanelsTabsSelectedNotKeyWndBackgroundColor();
}

- (NSColor *)regularKeyWndBackgroundColor
{
    return nc::CurrentTheme().FilePanelsTabsRegularKeyWndRegularBackgroundColor();
}

- (NSColor *)regularKeyWndHoverBackgroundColor
{
    return nc::CurrentTheme().FilePanelsTabsRegularKeyWndHoverBackgroundColor();
}

- (NSColor *)regularNotKeyWndBackgroundColor
{
    return nc::CurrentTheme().FilePanelsTabsRegularNotKeyWndBackgroundColor();
}

- (NSColor *)separatorColor
{
    return nc::CurrentTheme().FilePanelsTabsSeparatorColor();
}

- (NSColor *)pictogramColor
{
    return nc::CurrentTheme().FilePanelsTabsPictogramColor();
}

- (void)observeChangesWith:(void (^)(void))_callback
{
    assert(_callback);
    m_ThemeChangesObservation =
        m_ThemesManager->ObserveChanges(nc::ThemesManager::Notifications::FilePanelsTabs, [_callback] { _callback(); });
}

@end

// Copyright (C) 2014-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <Panel/UI/PanelTabBarView.h>

namespace nc {
class ThemesManager;
}

@interface NCPanelTabBarThemeProviderImpl : NSObject <NCPanelTabBarThemeProvider>
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithThemesManager:(nc::ThemesManager &)_themes_mgr;
@end

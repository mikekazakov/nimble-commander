// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <NimbleCommander/Core/Theming/Theme.h>

@interface PreferencesWindowThemesTabColorControl : NSControl
@property (nonatomic) NSColor *color;
@end

@interface PreferencesWindowThemesTabFontControl : NSControl
@property (nonatomic) NSFont *font;
@end

namespace nc::panel {
    struct PresentationItemsColoringRule;
}
@interface PreferencesWindowThemesTabColoringRulesControl : NSControl<NSTextFieldDelegate>
@property (nonatomic) vector<nc::panel::PresentationItemsColoringRule> rules;
@end

@interface PreferencesWindowThemesAppearanceControl : NSControl
@property (nonatomic) ThemeAppearance themeAppearance;
@end

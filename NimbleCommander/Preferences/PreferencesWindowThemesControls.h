// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <NimbleCommander/Core/Theming/Theme.h>

@interface NCPreferencesActionTableCellView : NSTableCellView

@property (nonatomic, nullable, weak) id target;
@property (nonatomic, nullable) SEL action;

- (BOOL)sendAction:(nullable SEL)action to:(nullable id)target;

@end

@interface PreferencesWindowThemesTabColorControl : 
    NCPreferencesActionTableCellView

@property (nonnull, nonatomic) NSColor *color;

@end

@interface PreferencesWindowThemesTabFontControl : NCPreferencesActionTableCellView

@property (nonnull, nonatomic) NSFont *font;

@end

namespace nc::panel {
    struct PresentationItemsColoringRule;
}
@interface PreferencesWindowThemesTabColoringRulesControl : 
    NCPreferencesActionTableCellView<NSTextFieldDelegate>

@property (nonatomic) std::vector<nc::panel::PresentationItemsColoringRule> rules;

@end

@interface PreferencesWindowThemesAppearanceControl : 
    NCPreferencesActionTableCellView

@property (nonatomic) ThemeAppearance themeAppearance;
@property (nonatomic) bool enabled;

@end

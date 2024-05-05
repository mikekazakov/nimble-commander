// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include <span>

@interface PreferencesWindowThemesTabAutomaticSwitchingSheet : SheetController

- (instancetype)initWithSwitchingSettings:(const nc::ThemesManager::AutoSwitchingSettings &)_autoswitching
                            andThemeNames:(std::span<const std::string>)_names;

@property(readonly, nonatomic) const nc::ThemesManager::AutoSwitchingSettings &settings;

@end

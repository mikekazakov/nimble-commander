// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>

@interface PreferencesWindowThemesTabImportSheet : SheetController

@property (nonatomic) bool overwriteCurrentTheme;
@property (nonatomic) bool importAsNewTheme;
@property (nonatomic) NSString *importAsName;


@end

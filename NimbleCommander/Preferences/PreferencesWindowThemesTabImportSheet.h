//
//  PreferencesWindowThemesTabImportSheet.h
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 1/26/17.
//  Copyright © 2017 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Utility/SheetController.h>

@interface PreferencesWindowThemesTabImportSheet : SheetController

@property (nonatomic) bool overwriteCurrentTheme;
@property (nonatomic) bool importAsNewTheme;
@property NSString *importAsName;


@end

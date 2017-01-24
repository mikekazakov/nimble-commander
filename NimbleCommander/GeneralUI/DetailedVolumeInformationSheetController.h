//
//  DetailedVolumeInformationSheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 22.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Utility/SheetController.h>

@interface DetailedVolumeInformationSheetController : SheetController

- (void)showSheetForWindow:(NSWindow *)_window withPath:(const string&)_path;

@end

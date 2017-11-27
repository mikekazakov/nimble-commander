// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include "PanelController.h"

@interface PanelController (Menu)

- (bool) validateActionBySelector:(SEL)_selector;

- (IBAction)OnFileViewCommand:(id)sender;
- (IBAction)OnGoToSavedConnectionItem:(id)sender;
- (IBAction)OnGoToFavoriteLocation:(id)sender;

@end

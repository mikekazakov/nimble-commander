#pragma once
#include "PanelController.h"

@interface PanelController (Menu)

- (IBAction)OnGoBack:(id)sender;
- (IBAction)OnGoToSavedConnectionItem:(id)sender;
- (IBAction)OnGoToFavoriteLocation:(id)sender;

@end

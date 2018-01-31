#pragma once

#include <Utility/MIMResponder.h>
#include "PanelViewKeystrokeSink.h"

@class PanelController;

@interface NCPanelControllerActionsDispatcher : AttachedResponder<NCPanelViewKeystrokeSink>

- (instancetype)initWithController:(PanelController*)_controller;


- (bool) validateActionBySelector:(SEL)_selector;

- (IBAction)OnFileViewCommand:(id)sender;
- (IBAction)OnGoToSavedConnectionItem:(id)sender;
- (IBAction)OnGoToFavoriteLocation:(id)sender;


@end

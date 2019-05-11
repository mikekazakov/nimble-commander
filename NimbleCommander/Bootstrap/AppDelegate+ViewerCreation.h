// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "AppDelegate.h"

@class NCViewerView;
@class InternalViewerController;

// this category is private to NCAppDelegate
@interface NCAppDelegate(ViewerCreation)

- (NCViewerView*) makeViewerWithFrame:(NSRect)frame;
- (InternalViewerController*) makeViewerController;
@end

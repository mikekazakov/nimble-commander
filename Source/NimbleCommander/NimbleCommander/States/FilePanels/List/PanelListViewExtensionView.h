// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@interface NCPanelListViewExtensionView : NSView

- (void)setExtension:(NSString *)_extension;

- (void)buildPresentation;

@end

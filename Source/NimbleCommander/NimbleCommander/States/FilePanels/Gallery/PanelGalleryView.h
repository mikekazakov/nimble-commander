// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../PanelViewImplementationProtocol.h"
#include "Layout.h"

@interface PanelGalleryView : NSView <NCPanelViewPresentationProtocol>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame;

@property(nonatomic) nc::panel::PanelGalleryViewLayout galleryLayout;

@end

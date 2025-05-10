// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../PanelViewImplementationProtocol.h"
#include "Layout.h"
#include <VFSIcon/IconRepository.h>

@interface PanelGalleryView : NSView <NCPanelViewPresentationProtocol, NSCollectionViewDataSource>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame andIR:(nc::vfsicon::IconRepository &)_ir;

@property(nonatomic) nc::panel::PanelGalleryViewLayout galleryLayout;

@end

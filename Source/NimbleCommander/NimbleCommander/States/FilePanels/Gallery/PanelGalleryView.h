// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../PanelViewImplementationProtocol.h"
#include "Layout.h"
#include <VFSIcon/IconRepository.h>

namespace nc::utility {
class UTIDB;
}

@class PanelView;

@interface NCPanelGalleryView
    : NSView <NCPanelViewPresentationProtocol, NSCollectionViewDelegate, NSCollectionViewDataSource>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame
               iconRepository:(nc::vfsicon::IconRepository &)_ir
                        UTIDB:(const nc::utility::UTIDB &)_UTIDB;

@property(nonatomic) nc::panel::PanelGalleryViewLayout galleryLayout;

// Provides access to the parent PanelView that contains this gallery view.
@property(nonatomic, readonly) PanelView *panelView;

@end

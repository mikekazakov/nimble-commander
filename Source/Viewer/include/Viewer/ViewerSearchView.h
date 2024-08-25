// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <Cocoa/Cocoa.h>

@interface NCViewerSearchView : NSView

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)frame;

@property(nonatomic, readonly) NSSearchField *searchField;

@property(nonatomic, readonly) NSProgressIndicator *progressIndicator;

@end

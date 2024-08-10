// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <Cocoa/Cocoa.h>
#include <Utility/Encodings.h>
#include "Modes.h"

@interface NCViewerFooter : NSView

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithFrame:(NSRect)frame;

@property(nonatomic, readwrite) nc::viewer::ViewMode mode; // KVO-compatible

@property(nonatomic, readwrite) nc::utility::Encoding encoding; // KVO-compatible

@property(nonatomic, readwrite) bool wrapLines; // KVO-compatible

@property(nonatomic, readwrite) uint64_t fileSize;

@end

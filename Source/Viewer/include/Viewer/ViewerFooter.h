// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <Cocoa/Cocoa.h>
#include <Utility/Encodings.h>
#include "Modes.h"

namespace nc::viewer::hl {
class SettingsStorage;
} // namespace nc::viewer::hl

@interface NCViewerFooter : NSView

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)_frame andHighlightingSyntaxStorage:(nc::viewer::hl::SettingsStorage &)_stor;

@property(nonatomic, readwrite) nc::viewer::ViewMode mode; // KVO-compatible

@property(nonatomic, readwrite) nc::utility::Encoding encoding; // KVO-compatible

@property(nonatomic, readwrite) bool wrapLines; // KVO-compatible

@property(nonatomic, readwrite) uint64_t fileSize;

@property(nonatomic, readwrite) NSString *filePosition;

@property(nonatomic, readwrite) const std::string &highlightingLanguage; // KVO-compatible

@property(nonatomic, readwrite, weak) id filePositionClickTarget;

@property(nonatomic, readwrite) SEL filePositionClickAction;

- (void)performFilePositionClick:(id)_sender;

@end

// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <Utility/Tags.h>
#include <span>

@class NCPanelViewFieldEditor;

@interface PanelListViewNameView : NSView

@property(nonatomic) NSImage *icon;

- (void)setFilename:(NSString *)_filename andTags:(std::span<const nc::utility::Tags::Tag>)_tags;

- (void)buildPresentation;

- (void)setupFieldEditor:(NCPanelViewFieldEditor *)_editor;

- (bool)dragAndDropHitTest:(NSPoint)_position; // local coordinates

@end

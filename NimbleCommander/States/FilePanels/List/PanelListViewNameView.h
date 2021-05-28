// Copyright (C) 2016-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@interface PanelListViewNameView : NSView

@property (nonatomic) NSImage *icon;

- (void) setFilename:(NSString*)_filename;

- (void) buildPresentation;

- (void) setupFieldEditor:(NSScrollView*)_editor;

- (bool) dragAndDropHitTest:(NSPoint)_position; // local coordinates

@end

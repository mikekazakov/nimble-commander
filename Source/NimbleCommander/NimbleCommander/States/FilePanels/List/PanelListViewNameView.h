// Copyright (C) 2016-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@class NCPanelViewFieldEditor;

@interface PanelListViewNameView : NSView

@property (nonatomic) NSImage *icon;

- (void) setFilename:(NSString*)_filename;

- (void) buildPresentation;

- (void) setupFieldEditor:(NCPanelViewFieldEditor*)_editor;

- (bool) dragAndDropHitTest:(NSPoint)_position; // local coordinates

@end

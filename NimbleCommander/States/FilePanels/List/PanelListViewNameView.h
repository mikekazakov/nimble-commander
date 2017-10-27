// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@interface PanelListViewNameView : NSView

@property (nonatomic) NSImage *icon;

- (void) setFilename:(NSString*)_filename;

- (void) buildPresentation;

- (void) setupFieldEditor:(NSScrollView*)_editor;

- (bool) dragAndDropHitTest:(NSPoint)_position; // local coordinates

@end

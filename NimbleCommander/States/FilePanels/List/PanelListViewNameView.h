#pragma once

@interface PanelListViewNameView : NSView

@property (nonatomic) NSImageRep *icon;

- (void) setFilename:(NSString*)_filename;

- (void) buildPresentation;

- (void) setupFieldEditor:(NSScrollView*)_editor;

- (bool) dragAndDropHitTest:(NSPoint)_position; // local coordinates

@end

#pragma once

@interface PanelListViewNameView : NSView

@property (nonatomic) NSImageRep *icon;

- (void) setFilename:(NSString*)_filename;

- (void) buildPresentation;

- (void) setupFieldEditor:(NSScrollView*)_editor;

@end

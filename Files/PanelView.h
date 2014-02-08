//
//  PanelView.h
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//
#pragma once

#import <Cocoa/Cocoa.h>

#import "PanelViewTypes.h"
#import "VFS.h"

@class PanelView;
class PanelData;
class PanelViewPresentation;

@protocol PanelViewDelegate<NSObject>
@optional
- (void) PanelViewCursorChanged:(PanelView*)_view;
- (void) PanelViewRequestsActivation:(PanelView*)_view;
- (void) PanelViewRequestsContextMenu:(PanelView*)_view;
- (void) PanelViewDoubleClick:(PanelView*)_view atElement:(int)_sort_pos;
- (void) PanelViewWantsDragAndDrop:(PanelView*)_view event:(NSEvent *)_event;
- (NSDragOperation)PanelViewDraggingEntered:(PanelView*)_view sender:(id <NSDraggingInfo>)sender;
- (NSDragOperation)PanelViewDraggingUpdated:(PanelView*)_view sender:(id <NSDraggingInfo>)sender;
- (BOOL) PanelViewPerformDragOperation:(PanelView*)_view sender:(id <NSDraggingInfo>)sender;

@end

@interface PanelView : NSView<NSDraggingDestination>
@property (weak) id <PanelViewDelegate> delegate;

- (void) SetPanelData:(PanelData*)_data;

- (void) DirectoryChanged:(const char*)_focused_filename;

// _presentation must be created using new. PanelView gains ownership of the _presentation.
- (PanelViewPresentation*) Presentation;
- (void) SetPresentation:(PanelViewPresentation *)_presentation;

// user input handling          normal keys
- (void) HandlePrevFile;     // up
- (void) HandleNextFile;     // down
- (void) HandlePrevPage;     // page up (fn+up)
- (void) HandleNextPage;     // page down (fn+down)
- (void) HandlePrevColumn;   // left
- (void) HandleNextColumn;   // right
- (void) HandleFirstFile;    // home (fn+left)
- (void) HandleLastFile;     // end (fn+right)
- (void) ModifierFlagsChanged:(unsigned long)_flags; // to know if shift or something else is pressed

//- (void) mouseDown:(NSEvent *)_event;
//- (void) mouseDragged:(NSEvent *)_event;
//- (void) mouseUp:(NSEvent *)_event;

// view type
- (void) ToggleViewType:(PanelViewType)_type;
- (PanelViewType) GetCurrentViewType;

// focus handling
- (void) Activate;
- (void) Disactivate;

// cursor handling
- (int) GetCursorPosition;
- (void) SetCursorPosition:(int)_pos; // will call EnsureCursorIsVisible implicitly
- (const VFSListingItem*) CurrentItem; // return an item at current cursor position if any

- (void) SavePathState;
- (void) LoadPathState;


@end

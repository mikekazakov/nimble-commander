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

@class PanelController;
class PanelData;
class PanelViewPresentation;


@interface PanelView : NSView

- (void) SetPanelController:(PanelController *)_controller;

- (void) SetPanelData:(PanelData*)_data;
- (void) DirectoryChanged:(PanelViewDirectoryChangeType)_type newcursor:(int)_cursor;

// _presentation must be created using new. PanelView gains ownership of the _presentation.
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

- (void) mouseDown:(NSEvent *)_event;
- (void) mouseDragged:(NSEvent *)_event;
- (void) mouseUp:(NSEvent *)_event;

- (void) UpdateQuickPreview;

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

@end

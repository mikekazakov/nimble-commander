//
//  PanelView.h
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//
#pragma once
#import <Cocoa/Cocoa.h>
#include "DirRead.h"

@class PanelController;
class PanelData;

enum class PanelViewType
{
    ViewShort,
    ViewMedium,
    ViewFull,
    ViewWide
};

enum class PanelViewDirectoryChangeType
{
    GoIntoSubDir,
    GoIntoParentDir,
    GoIntoOtherDir
};

@interface PanelView : NSView


- (void) SetPanelController:(PanelController *)_controller;
// directory traversing
- (void) SetPanelData: (PanelData*) _data;
//- (void) DirectoryChanged:(int) _new_curpos Type:(PanelViewDirectoryChangeType)_type;
- (void) DirectoryChanged:(PanelViewDirectoryChangeType)_type newcursor:(int)_cursor;

// TODO: consider moving the following code to PanelController class
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
- (void) EnsureCursorIsVisible;
- (int) GetCursorPosition;
- (void) SetCursorPosition:(int)_pos; // will call EnsureCursorIsVisible implicitly
- (const DirectoryEntryInformation*) CurrentItem; // return an item at current cursor position if any

// Calculates cursor postion which corresponds to the point in view.
// Returns -1 if point is out of files' view area.
- (int) CalcCursorPositionByPointInView:(CGPoint)_point;

@end

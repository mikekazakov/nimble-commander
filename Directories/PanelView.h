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

class PanelData;

enum class PanelViewType
{
    ViewShort,
    ViewMedium,
    ViewLarge
};

@interface PanelView : NSView

enum DirectoryChangeType
{
    GoIntoSubDir,
    GoIntoParentDir,
    GoIntoOtherDir
};

// directory traversing
- (void) SetPanelData: (PanelData*) _data;
- (void) DirectoryChanged:(int) _new_curpos Type:(DirectoryChangeType)_type;

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

// view type
- (void) ToggleViewType:(PanelViewType)_type;

// focus handling
- (void) Activate;
- (void) Disactivate;

// cursor handling
- (void) EnsureCursorIsVisible;
- (int) GetCursorPosition;
- (void) SetCursorPosition:(int)_pos; // will call EnsureCursorIsVisible implicitly
- (const DirectoryEntryInformation&) CurrentItem; // return an item at current cursor position

@end

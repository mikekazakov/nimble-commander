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
- (NSMenu*) PanelViewRequestsContextMenu:(PanelView*)_view;
- (void) PanelViewDoubleClick:(PanelView*)_view atElement:(int)_sort_pos;
- (void) PanelViewWantsDragAndDrop:(PanelView*)_view event:(NSEvent *)_event;
- (NSDragOperation)PanelViewDraggingEntered:(PanelView*)_view sender:(id <NSDraggingInfo>)sender;
- (NSDragOperation)PanelViewDraggingUpdated:(PanelView*)_view sender:(id <NSDraggingInfo>)sender;
- (BOOL) PanelViewPerformDragOperation:(PanelView*)_view sender:(id <NSDraggingInfo>)sender;
- (bool) PanelViewProcessKeyDown:(PanelView*)_view event:(NSEvent *)_event;

@end

@interface PanelView : NSView<NSDraggingDestination>
@property (nonatomic) id <PanelViewDelegate> delegate;
@property (nonatomic, readonly) bool active;
@property (nonatomic) int curpos; // will call EnsureCursorIsVisible implicitly on set
@property (nonatomic, readonly) const VFSListingItem* item; // return an item at current cursor position if any or nullptr
@property (nonatomic) PanelViewType type;

- (void) SetPanelData:(PanelData*)_data;

- (void) DirectoryChanged:(const char*)_focused_filename;

// _presentation must be created using new. PanelView gains ownership of the _presentation.
- (PanelViewPresentation*) Presentation;
- (void) SetPresentation:(PanelViewPresentation *)_presentation;
- (void) ModifierFlagsChanged:(unsigned long)_flags; // to know if shift or something else is pressed


- (void) SavePathState;
- (void) LoadPathState;

@end

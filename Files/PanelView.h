//
//  PanelView.h
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//
#pragma once

#include "vfs/VFS.h"
#include "PanelViewTypes.h"
#include "rapidjson.h"
#include "PanelData.h"

@class FPSLimitedDrawer;
@class PanelView;
class PanelViewPresentation;
struct PanelVolatileData;

@protocol PanelViewDelegate<NSObject>
@optional
- (void) PanelViewDidBecomeFirstResponder:(PanelView*)_view;
- (void) PanelViewCursorChanged:(PanelView*)_view;
- (NSMenu*) panelView:(PanelView*)_view requestsContextMenuForItemNo:(int)_sort_pos;
- (void) PanelViewDoubleClick:(PanelView*)_view atElement:(int)_sort_pos;
- (void) panelView:(PanelView*)_view wantsToDragItemNo:(int)_sort_pos byEvent:(NSEvent *)_event;
- (NSDragOperation)PanelViewDraggingEntered:(PanelView*)_view sender:(id <NSDraggingInfo>)sender;
- (NSDragOperation)PanelViewDraggingUpdated:(PanelView*)_view sender:(id <NSDraggingInfo>)sender;
- (void)PanelViewDraggingExited:(PanelView*)_view sender:(id <NSDraggingInfo>)sender;
- (BOOL) PanelViewPerformDragOperation:(PanelView*)_view sender:(id <NSDraggingInfo>)sender;
- (bool) PanelViewProcessKeyDown:(PanelView*)_view event:(NSEvent *)_event;

- (bool) PanelViewWantsRenameFieldEditor:(PanelView*)_view;
- (void) PanelViewRenamingFieldEditorFinished:(PanelView*)_view text:(NSString*)_filename;

@end

@interface PanelView : NSView<NSDraggingDestination, NSTextViewDelegate>
@property (nonatomic) id <PanelViewDelegate> delegate;
@property (nonatomic, readonly) bool active;
@property (nonatomic) int curpos; // will call EnsureCursorIsVisible implicitly on set
@property (nonatomic, readonly) VFSListingItem item; // return an item at current cursor position if any or nullptr
@property (nonatomic, readonly) const PanelData::PanelVolatileData& item_vd; // will return default-initialized default shared stub if there's no current item
@property (nonatomic) PanelViewType type;
@property (nonatomic) PanelData* data;
@property (nonatomic, readonly) FPSLimitedDrawer* fpsDrawer;
//@property (nonatomic, readonly) PanelViewPresentation* presentation;
@property (nonatomic, readonly) NSString* headerTitle; // KVO-bound

/**
 * Set to true to tell PanelView to drag focus ring. If draggingOverItemAtPosition<0 - draw focus ring in view bounds,
 * otherwise draw focus ring in specified item.
 * No KVO support here.
 */
@property (nonatomic) bool draggingOver;

/**
 * Tell PanelView to draw a focus ring over item at specified position.
 * draggingOver should be true, otherwise value ignored.
 * No KVO support here.
 */
@property (nonatomic) int draggingOverItemAtPosition;

- (void) setupContextMenuHighlights:(vector<int>)_positions;
- (void) resetContextMenuHighlights;

/**
 * called by controlled when a directory has been entirely changed in PanelData.
 * possibly focusing some file, may be "".
 */
- (void) panelChangedWithFocusedFilename:(const string&)_focused_filename loadPreviousState:(bool)_load;

/**
 * called by controller to inform that internals of panel data object has changed (possibly reloaded).
 * should be called before directoryChanged
 */
- (void) dataUpdated;

- (void) modifierFlagsChanged:(unsigned long)_flags; // to know if shift or something else is pressed

- (rapidjson::StandaloneValue) encodeRestorableState;
- (void) loadRestorableState:(const rapidjson::StandaloneValue&)_state;

- (void) SavePathState;
- (void) LoadPathState;

/**
 * _text can be nil.
 */
- (void) setQuickSearchPrompt:(NSString*)_text;

- (void) disableCurrentMomentumScroll;

/**
 * return a number of item at specified point.
 * options currently unsupported.
 */
- (int) sortedItemPosAtPoint:(NSPoint)_point hitTestOption:(PanelViewHitTest::Options)_options;

- (void) startFieldEditorRenaming;

@end

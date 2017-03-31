//
//  PanelView.h
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//
#pragma once

#include <VFS/VFS.h>
#include "../../Core/rapidjson.h"
#include "PanelData.h"
#include "PanelViewTypes.h"
//#include "PanelViewLayoutSupport.h"

//@class FPSLimitedDrawer;
@class PanelView;
struct PanelViewLayout;
//class PanelViewPresentation;
//struct PanelVolatileData;

@protocol PanelViewDelegate<NSObject>
@optional
//- (void) PanelViewDidBecomeFirstResponder:(PanelView*)_view;
- (void) PanelViewCursorChanged:(PanelView*)_view;
- (NSMenu*) panelView:(PanelView*)_view requestsContextMenuForItemNo:(int)_sort_pos;
- (void) PanelViewDoubleClick:(PanelView*)_view atElement:(int)_sort_pos;
- (BOOL) PanelViewPerformDragOperation:(PanelView*)_view sender:(id <NSDraggingInfo>)sender;
- (bool) PanelViewProcessKeyDown:(PanelView*)_view event:(NSEvent *)_event;

- (bool) PanelViewWantsRenameFieldEditor:(PanelView*)_view;
- (void) PanelViewRenamingFieldEditorFinished:(PanelView*)_view text:(NSString*)_filename;

@end

@interface PanelView : NSView<NSDraggingDestination, NSTextViewDelegate>
@property (nonatomic) id <PanelViewDelegate> delegate;
@property (nonatomic, readonly) bool active; // means that window is key and view is the first responder. KVO-compatible
@property (nonatomic) int curpos; // will call EnsureCursorIsVisible implicitly on set
@property (nonatomic, readonly) VFSListingItem item; // return an item at current cursor position if any or nullptr
@property (nonatomic, readonly) const PanelData::VolatileData& item_vd; // will return default-initialized default shared stub if there's no current item
//@property (nonatomic) PanelViewType type;
@property (nonatomic) PanelData* data;
@property (nonatomic, readonly) NSString* headerTitle; // KVO-bound
@property (nonatomic, readonly) int headerBarHeight;

- (id)initWithFrame:(NSRect)frame layout:(const PanelViewLayout&)_layout;

/**
 * called by controlled when a directory has been entirely changed in PanelData.
 * possibly focusing some file, may be "".
 */
- (void) panelChangedWithFocusedFilename:(const string&)_focused_filename loadPreviousState:(bool)_load;

/**
 * called by controller to inform that internals of panel data object has changed (possibly reloaded).
 * should be called before directoryChanged.
 * volatileDataChanged will be triggered automatically.
 */
- (void) dataUpdated;

- (void) dataSortingHasChanged;

- (void) volatileDataChanged;

//- (void) modifierFlagsChanged:(unsigned long)_flags; // to know if shift or something else is pressed

//- (rapidjson::StandaloneValue) encodeRestorableState;
//- (void) loadRestorableState:(const rapidjson::StandaloneValue&)_state;

- (void) SavePathState;
- (void) LoadPathState;

/**
 * _text can be nil.
 */
- (void) setQuickSearchPrompt:(NSString*)_text withMatchesCount:(int)_count;


/**
 * Configure and bring the popover to the screen.
 */
- (NSPopover*)showPopoverUnderPathBarWithView:(NSViewController*)_view
                                  andDelegate:(id<NSPopoverDelegate>)_delegate;

/**
 * return a number of item at specified point.
 * options currently unsupported.
 */
- (int) sortedItemPosAtPoint:(NSPoint)_window_point hitTestOption:(PanelViewHitTest::Options)_options;

- (void) startFieldEditorRenaming;

//PanelViewLayout
- (void) setLayout:(const PanelViewLayout&)_layout;

/*
 * PanelView implementation hooks.
 * Later: add hit-test info flags here.
 * _sorted_index==-1 means no specific item, i.e. free view area.
 */
- (void)panelItem:(int)_sorted_index mouseDown:(NSEvent*)_event;
- (void)panelItem:(int)_sorted_index mouseDragged:(NSEvent*)_event;
- (void)panelItem:(int)_sorted_index fieldEditor:(NSEvent*)_event;
- (void)panelItem:(int)_sorted_index dblClick:(NSEvent*)_event;
- (NSDragOperation)panelItem:(int)_sorted_index operationForDragging:(id<NSDraggingInfo>)_dragging;
- (bool)panelItem:(int)_sorted_index performDragOperation:(id<NSDraggingInfo>)_dragging;

- (NSMenu *)panelItem:(int)_sorted_index menuForForEvent:(NSEvent*)_event;

+ (NSArray*) acceptedDragAndDropTypes;

@end

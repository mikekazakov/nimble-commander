// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include <VFSIcon/IconRepository.h>
#include "PanelViewTypes.h"

#include <any>
#include <memory>
#include <Cocoa/Cocoa.h>


@protocol PanelViewDelegate;
@protocol NCPanelViewKeystrokeSink;
@class NCPanelControllerActionsDispatcher;
@class PanelView;
@class NCPanelViewHeader;
@class NCPanelViewFooter;

namespace nc::panel {
    struct PanelViewLayout;
    namespace data {
        struct ItemVolatileData;
        class Model;
    }
}

@interface PanelView : NSView<NSDraggingDestination>
@property (nonatomic) id <PanelViewDelegate> delegate;

/**
 * Means that window is key and view is the first responder. KVO-compatible.
 */
@property (nonatomic, readonly) bool active;
@property (nonatomic) int curpos; // will call EnsureCursorIsVisible implicitly on set
@property (nonatomic, readonly) VFSListingItem item; // return an item at current cursor position if any or nullptr
@property (nonatomic, readonly) const nc::panel::data::ItemVolatileData& item_vd; // will return default-initialized default shared stub if there's no current item
@property (nonatomic) nc::panel::data::Model* data;
@property (nonatomic, readonly) NSString* headerTitle; // KVO-bound
@property (nonatomic, readonly) int headerBarHeight;
@property (nonatomic, readonly) NSProgressIndicator *busyIndicator;
@property (nonatomic, readonly) NCPanelViewHeader *headerView;
@property (nonatomic, weak) NCPanelControllerActionsDispatcher* actionsDispatcher;

- (id)initWithFrame:(NSRect)frame
     iconRepository:(std::unique_ptr<nc::vfsicon::IconRepository>)_icon_repository
             header:(NCPanelViewHeader*)_header
             footer:(NCPanelViewFooter*)_footer;

/**
 * called by controlled when a directory has been entirely changed in PanelData.
 * possibly focusing some file, may be "".
 */
- (void) panelChangedWithFocusedFilename:(const std::string&)_focused_filename
                       loadPreviousState:(bool)_load;

/**
 * called by controller to inform that internals of panel data object has changed (possibly reloaded).
 * should be called before directoryChanged.
 * volatileDataChanged will be triggered automatically.
 */
- (void) dataUpdated;

- (void) dataSortingHasChanged;

- (void) volatileDataChanged;

- (void) savePathState;
- (void) loadPathState;

/**
 * Configure and bring the popover to the screen.
 */
- (NSPopover*)showPopoverUnderPathBarWithView:(NSViewController*)_view
                                  andDelegate:(id<NSPopoverDelegate>)_delegate;

/**
 * return a number of item at specified point.
 * options currently unsupported.
 */
- (int) sortedItemPosAtPoint:(NSPoint)_window_point hitTestOption:(nc::panel::PanelViewHitTest::Options)_options;

- (void) startFieldEditorRenaming;
- (void) discardFieldEditor;

//PanelViewLayout
- (std::any) presentationLayout;
- (void) setPresentationLayout:(const nc::panel::PanelViewLayout&)_layout;

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
- (void)notifyAboutPresentationLayoutChange;

- (NSMenu *)panelItem:(int)_sorted_index menuForForEvent:(NSEvent*)_event;

+ (NSArray*) acceptedDragAndDropTypes;

- (void)addKeystrokeSink:(id<NCPanelViewKeystrokeSink>)_sink withBasePriority:(int)_priority;
- (void)removeKeystrokeSink:(id<NCPanelViewKeystrokeSink>)_sink;

@end

// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include "../PanelView.h"
#include "PanelListViewTableView.h"
#include "Layout.h"
#include <Utility/ObjCpp.h>
#include <magic_enum.hpp>
#include <cmath>

using namespace nc;
using namespace nc::panel;

@interface PanelListViewTableView ()

@property(nonatomic) NSColor *alternateBackgroundColor;
@property(nonatomic) bool isDropTarget;

@end

@implementation PanelListViewTableView {
    bool m_IsDropTarget;
    ThemesManager::ObservationTicket m_ThemeObservation;
}
@synthesize alternateBackgroundColor;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        [self registerForDraggedTypes:PanelView.acceptedDragAndDropTypes];
        [self setupColors];

        __weak PanelListViewTableView *weak_self = self;
        m_ThemeObservation =
            NCAppDelegate.me.themesManager.ObserveChanges(ThemesManager::Notifications::FilePanelsList, [weak_self] {
                if( auto strong_self = weak_self )
                    [strong_self setupColors];
            });
    }
    return self;
}

- (void)setupColors
{
    self.backgroundColor = CurrentTheme().FilePanelsListRegularEvenRowBackgroundColor();
    self.alternateBackgroundColor = CurrentTheme().FilePanelsListRegularOddRowBackgroundColor();
    self.needsDisplay = true;
}

- (BOOL)acceptsFirstResponder
{
    return false;
}

- (BOOL)isOpaque
{
    return true;
}

- (void)addSubview:(NSView *)view
{
    if( [NSStringFromClass(view.class) isEqualToString:@"NSTableBackgroundView"] )
        return; // nope.
    [super addSubview:view];
}

- (void)addSubview:(NSView *) [[maybe_unused]] view
        positioned:(NSWindowOrderingMode) [[maybe_unused]] place
        relativeTo:(nullable NSView *) [[maybe_unused]] otherView
{
    if( [NSStringFromClass(view.class) isEqualToString:@"NSTableBackgroundView"] )
        return; // nope.
    [super addSubview:view positioned:place relativeTo:otherView];
}

- (PanelView *)panelView
{
    NSView *sv = self.superview;
    while( sv != nil && nc::objc_cast<PanelView>(sv) == nil )
        sv = sv.superview;
    return static_cast<PanelView *>(sv);
}

- (void)keyDown:(NSEvent *)event
{
    if( auto pv = self.panelView )
        [pv keyDown:event];
}

- (BOOL)acceptsFirstMouse:(nullable NSEvent *) [[maybe_unused]] _event
{
    return false;
}

- (void)mouseDown:(NSEvent *)event
{
    [self.panelView panelItem:-1 mouseDown:event];
}

- (void)mouseUp:(NSEvent *) [[maybe_unused]] _event
{
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    auto op = [self.panelView panelItem:-1 operationForDragging:sender];
    if( op != NSDragOperationNone ) {
        self.isDropTarget = true;
    }
    return op;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
    return [self draggingEntered:sender];
}

- (void)draggingExited:(id<NSDraggingInfo>) [[maybe_unused]] _sender
{
    self.isDropTarget = false;
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>) [[maybe_unused]] _sender
{
    // possibly add some checking stage here later
    return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    if( self.isDropTarget ) {
        self.isDropTarget = false;
        return [self.panelView panelItem:-1 performDragOperation:sender];
    }
    else
        return false;
}

- (bool)isDropTarget
{
    return m_IsDropTarget;
}

- (void)setIsDropTarget:(bool)isDropTarget
{
    if( m_IsDropTarget != isDropTarget ) {
        m_IsDropTarget = isDropTarget;
        if( m_IsDropTarget ) {
            self.layer.borderWidth = 1;
            self.layer.borderColor = CurrentTheme().FilePanelsGeneralDropBorderColor().CGColor;
        }
        else
            self.layer.borderWidth = 0;
    }
}

- (void)drawBackgroundInClipRect:(NSRect)clipRect
{
    if( [self alternateBackgroundColor] == nil ) {
        // If we didn't set the alternate colour, fall back to the default behaviour
        [super drawBackgroundInClipRect:clipRect];
    }
    else {
        // Fill in the background colour
        [[self backgroundColor] set];
        NSRectFill(clipRect);

        // Check if we should be drawing alternating coloured rows
        if( [self alternateBackgroundColor] && [self usesAlternatingRowBackgroundColors] ) {
            // Set the alternating background colour
            [[self alternateBackgroundColor] set];

            // Go through all of the intersected rows and draw their rects
            NSRect checkRect = [self bounds];
            checkRect.origin.y = clipRect.origin.y;
            checkRect.size.height = clipRect.size.height;
            NSRange rowsToDraw = [self rowsInRect:checkRect];
            NSUInteger curRow = rowsToDraw.location;
            while( curRow < rowsToDraw.location + rowsToDraw.length ) {
                if( curRow % 2 != 0 ) {
                    // This is an alternate row
                    NSRect rowRect = [self rectOfRow:curRow];
                    rowRect.origin.x = clipRect.origin.x;
                    rowRect.size.width = clipRect.size.width;
                    NSRectFill(rowRect);
                }

                curRow++;
            }

            // Figure out the height of "off the table" rows
            CGFloat rowHeight = [self rowHeight];
            if( ([self gridStyleMask] & NSTableViewSolidHorizontalGridLineMask) ==
                    NSTableViewSolidHorizontalGridLineMask ||
                ([self gridStyleMask] & NSTableViewDashedHorizontalGridLineMask) ==
                    NSTableViewDashedHorizontalGridLineMask ) {
                rowHeight += 2.0f; // Compensate for a grid
            }

            // Draw fake rows below the table's last row
            CGFloat virtualRowOrigin = 0.0f;
            NSInteger virtualRowNumber = [self numberOfRows];
            if( [self numberOfRows] > 0 ) {
                NSRect finalRect = [self rectOfRow:[self numberOfRows] - 1];
                virtualRowOrigin = finalRect.origin.y + finalRect.size.height;
            }
            while( virtualRowOrigin < clipRect.origin.y + clipRect.size.height ) {
                if( virtualRowNumber % 2 != 0 ) {
                    // This is an alternate row
                    NSRect virtualRowRect =
                        NSMakeRect(clipRect.origin.x, virtualRowOrigin, clipRect.size.width, rowHeight);
                    NSRectFill(virtualRowRect);
                }

                virtualRowNumber++;
                virtualRowOrigin += rowHeight;
            }

            // Draw fake rows above the table's first row
            virtualRowOrigin = -1 * rowHeight;
            virtualRowNumber = -1;
            while( virtualRowOrigin + rowHeight > clipRect.origin.y ) {
                if( abs(virtualRowNumber) % 2 != 0 ) {
                    // This is an alternate row
                    NSRect virtualRowRect =
                        NSMakeRect(clipRect.origin.x, virtualRowOrigin, clipRect.size.width, rowHeight);
                    NSRectFill(virtualRowRect);
                }

                virtualRowNumber--;
                virtualRowOrigin -= rowHeight;
            }
        }
    }

    // now manually draw the vertical separator lines
    const auto separator_color = self.gridColor;
    if( separator_color && separator_color != NSColor.clearColor ) {
        std::array<double, magic_enum::enum_count<PanelListViewColumns>() + 1> x_offset;
        size_t columns_number = 0;
        for( NSTableColumn *column in self.tableColumns ) {
            assert(columns_number < x_offset.size());
            x_offset[columns_number] =
                columns_number == 0 ? column.width - 1. : x_offset[columns_number - 1] + column.width;
            ++columns_number;
        }
        if( columns_number != 0 && x_offset[columns_number - 1] >= self.bounds.size.width - 1 ) {
            // don't draw the last column separator if it's exactly next to end of the table view
            // (just looks ugly)
            --columns_number;
        }

        [separator_color set];
        for( size_t i = 0; i != columns_number; ++i ) {
            NSRect rc;
            rc.origin.x = x_offset[i];
            rc.origin.y = clipRect.origin.y;
            rc.size.width = 1.;
            rc.size.height = clipRect.size.height;
            rc = NSIntersectionRect(rc, clipRect);
            if( !NSIsEmptyRect(rc) )
                NSRectFill(rc);
        }
    }
}

+ (void)drawVerticalSeparatorForView:(NSView *)_view
{
    const auto table = nc::objc_cast<NSTableView>(_view.superview.superview);
    if( !table )
        return;

    const auto color = table.gridColor;

    if( color && color != NSColor.clearColor ) {
        const auto bounds = _view.bounds;
        const auto rc = NSMakeRect(std::ceil(bounds.size.width) - 1, 0, 1, bounds.size.height);

        // don't draw vertical line near table view's edge
        const auto trc = [table convertRect:rc fromView:_view];
        if( trc.origin.x < table.bounds.size.width - 1 ) {
            [color set];
            NSRectFill(rc); // support alpha?
        }
    }
}

@end

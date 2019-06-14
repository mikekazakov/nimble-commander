// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include "../PanelView.h"
#include "PanelListViewTableView.h"
#include <Utility/ObjCpp.h>

@interface PanelListViewTableView()

@property (nonatomic)  NSColor *alternateBackgroundColor;
@property (nonatomic) bool isDropTarget;

@end

@implementation PanelListViewTableView
{
    bool m_IsDropTarget;
    ThemesManager::ObservationTicket    m_ThemeObservation;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        [self registerForDraggedTypes:PanelView.acceptedDragAndDropTypes];
        [self setupColors];
        
        __weak PanelListViewTableView* weak_self = self;
        m_ThemeObservation = NCAppDelegate.me.themesManager.ObserveChanges(
            ThemesManager::Notifications::FilePanelsList, [weak_self]{
            if( auto strong_self = weak_self )
                [strong_self setupColors];
        });
    }
    return self;
}

- (void) setupColors
{
    self.backgroundColor = CurrentTheme().FilePanelsListRegularEvenRowBackgroundColor();
    self.alternateBackgroundColor = CurrentTheme().FilePanelsListRegularOddRowBackgroundColor();
    self.needsDisplay = true;
}

- (BOOL)acceptsFirstResponder
{
    return false;
}

- (BOOL)isOpaque {
    return true;
}

- (PanelView*)panelView
{
    NSView *sv = self.superview;
    while( sv != nil && objc_cast<PanelView>(sv) == nil )
        sv = sv.superview;
    return (PanelView*)sv;
}

- (void)keyDown:(NSEvent *)event
{
    if( auto pv = self.panelView )
        [pv keyDown:event];
}

- (BOOL)acceptsFirstMouse:(nullable NSEvent *)[[maybe_unused]]_event
{
    return false;
}

- (void)mouseDown:(NSEvent *)event
{
    [self.panelView panelItem:-1 mouseDown:event];
}

- (void)mouseUp:(NSEvent *)[[maybe_unused]]_event
{
}

//- (void)drawBackgroundInClipRect:(NSRect)clipRect
//{
//    
//    
//}

//- (void)drawRow:(NSInteger)row clipRect:(NSRect)clipRect {}
//- (void)highlightSelectionInClipRect:(NSRect)clipRect {}
//- (void)drawGridInClipRect:(NSRect)clipRect {}
//- (void)drawBackgroundInClipRect:(NSRect)clipRect {}
//
//
//- (void)display{}
//- (void)displayIfNeeded{}
//- (void)displayIfNeededIgnoringOpacity{}
//- (void)displayRect:(NSRect)rect{}
//- (void)displayIfNeededInRect:(NSRect)rect{}
//- (void)displayRectIgnoringOpacity:(NSRect)rect{}
//- (void)displayIfNeededInRectIgnoringOpacity:(NSRect)rect{}
//- (void)drawRect:(NSRect)dirtyRect{}
//- (void)displayRectIgnoringOpacity:(NSRect)rect inContext:(NSGraphicsContext *)context{}


- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    auto op = [self.panelView panelItem:-1 operationForDragging:sender];
    if( op != NSDragOperationNone ) {
        self.isDropTarget = true;
    }
    return op;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    return [self draggingEntered:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)[[maybe_unused]]_sender
{
    self.isDropTarget = false;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)[[maybe_unused]]_sender
{
    // possibly add some checking stage here later
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    if( self.isDropTarget ) {
        self.isDropTarget = false;
        return [self.panelView panelItem:-1 performDragOperation:sender];
    }
    else
        return false;
}

- (bool) isDropTarget
{
    return m_IsDropTarget;
}

- (void) setIsDropTarget:(bool)isDropTarget
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

- (void) drawBackgroundInClipRect:(NSRect)clipRect {

    if( [self alternateBackgroundColor] == nil ) {
        // If we didn't set the alternate colour, fall back to the default behaviour
        [super drawBackgroundInClipRect:clipRect];
    } else {
        // Fill in the background colour
        [[self backgroundColor] set];
        NSRectFill(clipRect);
        
        // Check if we should be drawing alternating coloured rows
        if([self alternateBackgroundColor] && [self usesAlternatingRowBackgroundColors]) {
            // Set the alternating background colour
            [[self alternateBackgroundColor] set];

            // Go through all of the intersected rows and draw their rects
            NSRect checkRect = [self bounds];
            checkRect.origin.y = clipRect.origin.y;
            checkRect.size.height = clipRect.size.height;
            NSRange rowsToDraw = [self rowsInRect:checkRect];
            NSUInteger curRow = rowsToDraw.location;
            while(curRow < rowsToDraw.location + rowsToDraw.length) {
                if(curRow % 2 != 0) {
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
            if( ([self gridStyleMask] & NSTableViewSolidHorizontalGridLineMask) == NSTableViewSolidHorizontalGridLineMask
               || ([self gridStyleMask] & NSTableViewDashedHorizontalGridLineMask) == NSTableViewDashedHorizontalGridLineMask) {
                rowHeight += 2.0f; // Compensate for a grid
            }

            // Draw fake rows below the table's last row
            CGFloat virtualRowOrigin = 0.0f;
            NSInteger virtualRowNumber = [self numberOfRows];
            if([self numberOfRows] > 0) {
                NSRect finalRect = [self rectOfRow:[self numberOfRows]-1];
                virtualRowOrigin = finalRect.origin.y + finalRect.size.height;
            }
            while(virtualRowOrigin < clipRect.origin.y + clipRect.size.height) {
                if(virtualRowNumber % 2 != 0) {
                    // This is an alternate row
                    NSRect virtualRowRect = NSMakeRect(clipRect.origin.x,virtualRowOrigin,clipRect.size.width,rowHeight);
                    NSRectFill(virtualRowRect);
                }

                virtualRowNumber++;
                virtualRowOrigin += rowHeight;
            }

            // Draw fake rows above the table's first row
            virtualRowOrigin = -1 * rowHeight;
            virtualRowNumber = -1;
            while(virtualRowOrigin + rowHeight > clipRect.origin.y) {
                if(abs(virtualRowNumber) % 2 != 0) {
                    // This is an alternate row
                    NSRect virtualRowRect = NSMakeRect(clipRect.origin.x,virtualRowOrigin,clipRect.size.width,rowHeight);
                    NSRectFill(virtualRowRect);
                }

                virtualRowNumber--;
                virtualRowOrigin -= rowHeight;
            }
        }
    }
}


@end

// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Core/Theming/Theme.h>
#include "PanelListViewTableHeaderCell.h"

@implementation PanelListViewTableHeaderCell

static void FillRect( NSRect rc, NSColor *c )
{
    [c set];
    if( c.alphaComponent == 1. )
        NSRectFill(rc);
    else
        NSRectFillUsingOperation(rc, NSCompositingOperationSourceOver);
}

- (void) drawBackgroundWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    [CurrentTheme().FilePanelsListHeaderBackgroundColor() set];
    NSRectFill(cellFrame);
  
    if( [self cellAttribute:NSCellState] ) {
        const auto original = CurrentTheme().FilePanelsListHeaderBackgroundColor();
        const auto colorspace = NSColorSpace.genericRGBColorSpace;
        const auto brightness = [original colorUsingColorSpace:colorspace].brightnessComponent;
        const auto new_color = [NSColor colorWithWhite:1.-brightness alpha:0.1];
        FillRect(NSMakeRect(cellFrame.origin.x,
                            cellFrame.origin.y,
                            cellFrame.size.width-1,
                            cellFrame.size.height),
                 new_color);
    }
}

- (void) drawHorizontalSeparatorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    FillRect(NSMakeRect(cellFrame.origin.x,
                        NSMaxY(cellFrame)-1,
                        cellFrame.size.width,
                        1),
             CurrentTheme().FilePanelsListHeaderSeparatorColor()
             );
}

- (void) drawVerticalSeparatorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    if( NSMaxX(cellFrame) < controlView.bounds.size.width )
        FillRect(NSMakeRect(NSMaxX(cellFrame)-1,
                            NSMinY(cellFrame)+3,
                            1,
                            cellFrame.size.height-6),
                 CurrentTheme().FilePanelsListHeaderSeparatorColor()
                 );
}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    [self drawBackgroundWithFrame:cellFrame inView:controlView];
    [self drawHorizontalSeparatorWithFrame:cellFrame inView:controlView];
    [self drawVerticalSeparatorWithFrame:cellFrame inView:controlView];

    // this may be really bad - to set attributes on every call.
    // might need to figure out a better way to customize header cells
    auto attrs = @{NSFontAttributeName: CurrentTheme().FilePanelsListHeaderFont(),
                   NSForegroundColorAttributeName: CurrentTheme().FilePanelsListHeaderTextColor(),
                   NSParagraphStyleAttributeName: [&]()->NSParagraphStyle*{
                       NSMutableParagraphStyle *ps = NSParagraphStyle.
                        defaultParagraphStyle.mutableCopy;
                       ps.alignment = self.alignment;
                       ps.lineBreakMode = NSLineBreakByClipping;
                       return ps;
                   }()
                   };
    self.attributedStringValue = [[NSAttributedString alloc] initWithString:self.stringValue
                                                                 attributes:attrs];
    
    const auto left_padding = 4;
    auto trc = [self drawingRectForBounds:cellFrame];

    const auto font_height = CurrentTheme().FilePanelsListHeaderFont().pointSize;
    const auto top = (trc.size.height - font_height) / 2;
    const auto height = font_height + 4;
    
    if( self.alignment == NSTextAlignmentRight ) {
        trc = NSMakeRect(trc.origin.x,
                         top,
                         trc.size.width,
                         height);
    }
    else if( self.alignment == NSTextAlignmentLeft )
        trc = NSMakeRect(trc.origin.x + left_padding,
                         top,
                         trc.size.width - left_padding,
                         height);
    else // center
        trc = NSMakeRect(trc.origin.x,
                         top,
                         trc.size.width,
                         height);
    [self drawInteriorWithFrame:trc inView:controlView];
}

@end

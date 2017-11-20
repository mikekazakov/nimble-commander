// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Core/Theming/Theme.h>
#include "PanelBriefViewCollectionViewBackground.h"
#include "PanelBriefViewCollectionViewLayout.h"
#include "PanelBriefView.h"

@implementation PanelBriefViewCollectionViewBackground
{
    int         m_RowHeight;
}

@synthesize rowHeight = m_RowHeight;

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_RowHeight = 20;
    }
    return self;
}

- (BOOL) isFlipped
{
    return true;
}

- (BOOL) isOpaque
{
    return true;
}

- (BOOL) wantsDefaultClipping
{
    return false;
}

- (NSCollectionView*)collectionView
{
    return objc_cast<NSCollectionView>(self.superview);
}

- (PanelBriefView*)briefView
{
    return objc_cast<PanelBriefView>(self.collectionView.delegate);
}

- (PanelBriefViewCollectionViewLayout*)viewLayout
{
    return objc_cast<PanelBriefViewCollectionViewLayout>(self.collectionView.collectionViewLayout);
}

- (void)drawRect:(NSRect)dirtyRect
{
    [self drawStripes:dirtyRect];
    [self drawGrid:dirtyRect];
}

- (void)drawStripes:(NSRect)dirtyRect
{
    const auto context = NSGraphicsContext.currentContext.CGContext;
    const auto top = (int)dirtyRect.origin.y;
    const auto bottom = (int)(dirtyRect.origin.y + dirtyRect.size.height);
    for( int y = top; y < bottom; y += m_RowHeight - ( y % m_RowHeight ) ) {
        auto c = (y / m_RowHeight) % 2 ?
            CurrentTheme().FilePanelsBriefRegularOddRowBackgroundColor() :
            CurrentTheme().FilePanelsBriefRegularEvenRowBackgroundColor();
        CGContextSetFillColorWithColor(context, c.CGColor);
        CGContextFillRect(context,
                          CGRectMake(dirtyRect.origin.x, y, dirtyRect.size.width, m_RowHeight)
                          );
    }
}

- (void)drawGrid:(NSRect)dirtyRect
{
    static const bool draws_grid =
        [self.collectionView respondsToSelector:@selector(setBackgroundViewScrollsWithContent:)];
    if( !draws_grid )
        return;

    const auto context = NSGraphicsContext.currentContext.CGContext;

    if( const auto cv = self.collectionView ) {
        if( const auto layout = self.viewLayout ) {
            if( const auto brief = self.briefView ) {
                const auto color = CurrentTheme().FilePanelsBriefGridColor();
                CGContextSetFillColorWithColor(context, color.CGColor);
                
                const auto &column_origins = layout.columnPositions;
                const auto valid_columns = brief.columns;
                const auto dirty_start = (int)dirtyRect.origin.x;
                const auto dirty_end = dirty_start + (int)dirtyRect.size.width;
                for( int i = 0, e = min((int)column_origins.size(), valid_columns); i < e; ++i ) {
                    const int origin = column_origins[i];
                    if( origin == numeric_limits<int>::max() )
                        continue;
                    if( origin < dirty_start  ) {
                    }
                    else if( origin >= dirty_end ) {
                        break;
                    }
                    else {
                        const auto rc = CGRectMake(origin-1,
                                                   dirtyRect.origin.y,
                                                   1,
                                                   dirtyRect.size.height);
                        CGContextFillRect(context, rc);
                    }
                }
                
                if( valid_columns > 0 ) {
                    const auto &column_widths = layout.columnWidths;
                    const auto origin = column_origins[valid_columns - 1];
                    const auto width = column_widths[valid_columns - 1];
                    if( origin != numeric_limits<int>::max() &&
                        width != 0 &&
                        origin >= dirty_start &&
                        origin + width - 1 < dirty_end ) {
                        const auto rc = CGRectMake(origin + width - 1,
                                                   dirtyRect.origin.y,
                                                   1,
                                                   dirtyRect.size.height);
                        CGContextFillRect(context, rc);
                    }
                }
            }
        }
    }
}

- (void) setRowHeight:(int)rowHeight
{
    if( rowHeight != m_RowHeight ) {
        m_RowHeight = rowHeight;
        [self setNeedsDisplay:true];
    }
}

@end

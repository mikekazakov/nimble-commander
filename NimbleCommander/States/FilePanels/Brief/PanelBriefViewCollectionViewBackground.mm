// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelBriefViewCollectionViewBackground.h"
#include "PanelBriefViewLayoutProtocol.h"
#include <NimbleCommander/Core/Theming/Theme.h>
#include <Utility/ObjCpp.h>

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

- (NSCollectionViewLayout<NCPanelBriefViewLayoutProtocol>*)viewLayout
{
    auto layout = self.collectionView.collectionViewLayout;
    return objc_cast<NSCollectionViewLayout<NCPanelBriefViewLayoutProtocol>>(layout);
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

- (void)drawGrid:(NSRect)_dirty_rect
{
    static const bool draws_grid =
        [self.collectionView respondsToSelector:@selector(setBackgroundViewScrollsWithContent:)];
    if( !draws_grid )
        return;

    const auto layout = self.viewLayout;
    if( layout == nil )
        return;
    
    const auto &column_widths = layout.columnsWidths;
    const auto &column_origins = layout.columnsPositions;
    if( column_origins.empty() )
        return;
    
    const auto context = NSGraphicsContext.currentContext.CGContext;
    const auto color = CurrentTheme().FilePanelsBriefGridColor();
    CGContextSetFillColorWithColor(context, color.CGColor);
    
    const auto draw_vline_at = [&](int _x){
        const auto rc = CGRectMake(_x, _dirty_rect.origin.y, 1, _dirty_rect.size.height);
        CGContextFillRect(context, rc);                               
    }; 
    
    const auto dirty_start = (int)_dirty_rect.origin.x;
    const auto dirty_end = dirty_start + (int)_dirty_rect.size.width;
    const auto first = std::lower_bound(column_origins.begin(), column_origins.end(), dirty_start);
    const auto last = std::lower_bound(column_origins.begin(), column_origins.end(), dirty_end);
    for( auto it = first; it < last; ++it )
        draw_vline_at( *it - 1 );                                        
    
    const auto right_border_pos = column_origins.back() + column_widths.back() - 1;
    if( right_border_pos >= dirty_start && right_border_pos < dirty_end )
        draw_vline_at( right_border_pos );
}

- (void) setRowHeight:(int)rowHeight
{
    if( rowHeight != m_RowHeight ) {
        m_RowHeight = rowHeight;
        [self setNeedsDisplay:true];
    }
}

@end

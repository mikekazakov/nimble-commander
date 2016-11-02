#include "../PanelListView.h"
//#include "PanelListViewDateFormatting.h"
#include "PanelListViewGeometry.h"
#include "PanelListViewRowView.h"
#include "PanelListViewDateTimeView.h"

@implementation PanelListViewDateTimeView
{
    time_t          m_Time;
    NSString       *m_String;
    PanelListViewDateFormatting::Style m_Style;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_Time = 0;
        m_String = @"";
        m_Style = PanelListViewDateFormatting::Style::Orthodox;
    }
    return self;
}

- (BOOL) isOpaque
{
    return true;
}

- (BOOL) wantsDefaultClipping
{
    return false;
}

- (void) setTime:(time_t)time
{
    if( m_Time != time ) {
        m_Time = time;
        [self buildString];
    }
}

- (PanelListViewDateFormatting::Style)style
{
    return m_Style;
}

- (void) setStyle:(PanelListViewDateFormatting::Style)style
{
    if( m_Style != style ) {
        m_Style = style;
        [self buildString];
    }
}

- (void) buildString
{
    m_String = PanelListViewDateFormatting::Format(m_Style, m_Time);
    [self setNeedsDisplay:true];
}

- (time_t) time
{
    return m_Time;
}

- (void) drawRect:(NSRect)dirtyRect
{
    if( auto rv = objc_cast<PanelListViewRowView>(self.superview) ) {
        if( auto lv = rv.listView ) {
            const auto bounds = self.bounds;
            const auto geometry = lv.geometry;
            
            const auto context = NSGraphicsContext.currentContext.CGContext;
            rv.rowBackgroundDoubleColor.Set( context );
//            CGContextSetFillColorWithColor(context, rv.rowBackgroundColor.CGColor);
            CGContextFillRect(context, NSRectToCGRect(self.bounds));
            
            const auto text_rect = NSMakeRect(geometry.LeftInset(),
                                              geometry.TextBaseLine(),
                                              bounds.size.width -  geometry.LeftInset() - geometry.RightInset(),
                                              0);
            [m_String drawWithRect:text_rect
                           options:0
                        attributes:rv.dateTimeViewTextAttributes
                           context:nil];
        }
    }
}

- (void) buildPresentation
{
    [self setNeedsDisplay:true];
}

@end

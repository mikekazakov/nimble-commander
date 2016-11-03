#include "../PanelListView.h"
//#include "PanelListViewDateFormatting.h"
#include "PanelListViewGeometry.h"
#include "PanelListViewRowView.h"
#include "PanelListViewDateTimeView.h"

@implementation PanelListViewDateTimeView
{
    time_t          m_Time;
    NSString       *m_String;
    CTLineRef       m_Line;
    PanelListViewDateFormatting::Style m_Style;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_Time = 0;
        m_Line = nullptr;
        m_String = @"";
        m_Style = PanelListViewDateFormatting::Style::Orthodox;
    }
    return self;
}

- (void) dealloc
{
    if( m_Line )
        CFRelease( m_Line );
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
    if( m_Line ) {
        CFRelease( m_Line );
        m_Line = nullptr;
    }
    [self buildLine];
    if( dispatch_is_main_queue() )
        [self setNeedsDisplay:true];
    else
        dispatch_to_main_queue([=]{
            [self setNeedsDisplay:true];
        });
}

- (void) buildLine
{
    if( auto rv = objc_cast<PanelListViewRowView>(self.superview) ) {
        if( auto lv = rv.listView ) {
            if( m_Line  )
                CFRelease( m_Line );
            
            NSAttributedString *as = [[NSAttributedString alloc] initWithString:m_String
                                                                     attributes:@{NSFontAttributeName: lv.font,
                                                                                  (NSString*)kCTForegroundColorFromContextAttributeName: @YES}
                                      ];
            m_Line = CTLineCreateWithAttributedString( (CFAttributedStringRef)as);
        }
    }
}

- (time_t) time
{
    return m_Time;
}

- (void) drawRect:(NSRect)dirtyRect
{
    //CTLineRef
    //CGContextShowText
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
//            [m_String drawAtPoint:<#(NSPoint)#> withAttributes:<#(nullable NSDictionary<NSString *,id> *)#>
            
            
/*            NSAttributedString *as = [[NSAttributedString alloc] initWithString:m_String
                                                                     attributes:@{NSFontAttributeName: lv.font,
                                                                                  (NSString*)kCTForegroundColorFromContextAttributeName:@YES
                                                                                  }];*/
//            kCTFontAttributeName
//            NSFontAttributeName: list_view.font,
            
//            CTLineRef line = CTLineCreateWithAttributedString( (CFAttributedStringRef)as);
            //CGContextSetFillColorWithColor(context, NSColor.yellowColor.CGColor);
            //CGContextSetStrokeColorWithColor(context, NSColor.yellowColor.CGColor);
            
            if( m_Line == nullptr )
                [self buildLine];
            
            rv.rowTextDoubleColor.Set( context );
            CGContextSetTextPosition( context, geometry.LeftInset(), geometry.TextBaseLine() );
            CGContextSetTextDrawingMode( context, kCGTextFill );
            CTLineDraw(m_Line, context);
  //          CFRelease(line);
            
            /*[m_String drawWithRect:text_rect
                           options:0
                        attributes:rv.dateTimeViewTextAttributes
                           context:nil];*/
        }
    }
}

- (void) buildPresentation
{
    [self setNeedsDisplay:true];
}

@end

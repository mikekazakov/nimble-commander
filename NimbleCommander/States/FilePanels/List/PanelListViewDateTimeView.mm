#include "../PanelListView.h"
//#include "PanelListViewDateFormatting.h"
#include "PanelListViewGeometry.h"
#include "PanelListViewRowView.h"
#include "PanelListViewDateTimeView.h"

static NSParagraphStyle *ParagraphStyle( NSLineBreakMode _mode )
{
    static NSParagraphStyle *styles[3];
    static once_flag once;
    call_once(once, []{
        NSMutableParagraphStyle *p0 = [NSMutableParagraphStyle new];
        p0.alignment = NSTextAlignmentLeft;
        p0.lineBreakMode = NSLineBreakByTruncatingHead;
        styles[0] = p0;
        
        NSMutableParagraphStyle *p1 = [NSMutableParagraphStyle new];
        p1.alignment = NSTextAlignmentLeft;
        p1.lineBreakMode = NSLineBreakByTruncatingTail;
        styles[1] = p1;
        
        NSMutableParagraphStyle *p2 = [NSMutableParagraphStyle new];
        p2.alignment = NSTextAlignmentLeft;
        p2.lineBreakMode = NSLineBreakByTruncatingMiddle;
        styles[2] = p2;
    });
    
    switch( _mode ) {
        case NSLineBreakByTruncatingHead:   return styles[0];
        case NSLineBreakByTruncatingTail:   return styles[1];
        case NSLineBreakByTruncatingMiddle: return styles[2];
        default:                            return nil;
    }
}


@implementation PanelListViewDateTimeView
{
    time_t          m_Time;
    NSString       *m_String;
    NSDictionary   *m_TextAttributes;
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

// 0:
// some orthodox fixed time formatting

// 1:
//formatter.dateStyle = NSDateFormatterLongStyle;
//formatter.timeStyle = NSDateFormatterShortStyle;

// 2:
//formatter.dateStyle = NSDateFormatterMediumStyle;
//formatter.timeStyle = NSDateFormatterShortStyle;

// 3:
//formatter.dateStyle = NSDateFormatterShortStyle;
//formatter.timeStyle = NSDateFormatterShortStyle;

// 4:
//formatter.dateStyle = NSDateFormatterShortStyle;
//formatter.timeStyle = NSDateFormatterNoStyle;
// for today:
//formatter.dateStyle = NSDateFormatterNoStyle;
//formatter.timeStyle = NSDateFormatterShortStyle;





- (void) setTime:(time_t)time
{
    if( m_Time != time ) {
        m_Time = time;
        
        [self buildString];
        
//        m_String = PanelListViewDateFormatting::Format(PanelListViewDateFormatting::Style::Long, time);
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

//    PanelListViewDateFormatting::Style m_Style;

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
            CGContextSetFillColorWithColor(context, rv.rowBackgroundColor.CGColor);
            CGContextFillRect(context, NSRectToCGRect(self.bounds));
            
            const auto text_rect = NSMakeRect(geometry.LeftInset(),
                                              geometry.TextBaseLine(),
                                              bounds.size.width -  geometry.LeftInset() - geometry.RightInset(),
                                              0);
            [m_String drawWithRect:text_rect
                           options:0
                        attributes:m_TextAttributes];
        }
    }
}

- (void) buildPresentation
{
//    NSDateFormatter
    
    if( PanelListViewRowView *row_view = (PanelListViewRowView*)self.superview ) {
//        if( auto item = row_view.item )
//            m_String = FileSizeToString(item,
//                                        row_view.vd,
//                                        ByteCountFormatter::Type::Adaptive8);
        
        m_TextAttributes = @{NSFontAttributeName:row_view.listView.font,
                             NSForegroundColorAttributeName: row_view.rowTextColor,
                             NSParagraphStyleAttributeName: ParagraphStyle(NSLineBreakByTruncatingMiddle)};
        
        [self setNeedsDisplay:true];
    }
}


@end

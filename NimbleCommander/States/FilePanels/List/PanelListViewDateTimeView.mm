// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelListView.h"
#include "PanelListViewGeometry.h"
#include "PanelListViewRowView.h"
#include "PanelListViewDateTimeView.h"
#include <NimbleCommander/Core/Theming/Theme.h>

@interface PanelListViewDateTimeView()

@property (nonatomic) NSFont *font;

@end

@implementation PanelListViewDateTimeView
{
    time_t          m_Time;
    NSString       *m_String;
    NSFont         *m_Font;
    CTLineRef       m_Line;
    PanelListViewDateFormatting::Style m_Style;
    __weak PanelListViewRowView *m_RowView;    
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_Time = 0;
        m_Line = nullptr;
        m_String = @"";
        m_Style = PanelListViewDateFormatting::Style::Orthodox;
        m_Font = CurrentTheme().FilePanelsListFont();
    }
    return self;
}

- (void) dealloc
{
    if( m_Line )
        CFRelease( m_Line );
}

- (BOOL) acceptsFirstMouse:(NSEvent *)theEvent
{
    /* really always??? */
    return true;
}

- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *)theEvent
{
    /* really always??? */
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

- (void)viewDidMoveToSuperview
{
    [super viewDidMoveToSuperview];
    if( auto rv = objc_cast<PanelListViewRowView>(self.superview) )
        m_RowView = rv;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    m_Time = 0;
    m_Line = nullptr;
    m_String = @"";
    m_Style = PanelListViewDateFormatting::Style::Orthodox;
    m_Font = CurrentTheme().FilePanelsListFont();
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

- (NSFont*) font
{
    return m_Font;
}

- (void) setFont:(NSFont *)font
{
    if( font != m_Font ) {
        m_Font = font;
        [self buildLine];
    }
}

- (void) buildString
{
    const auto new_string = [&]{
        if( m_Time >= 0 ) {
            auto dts = PanelListViewDateFormatting::Format(m_Style, m_Time);
            return dts ? dts : @"";
        }
        else
            return @"--";
    }();
    
    if( ![new_string isEqualToString:m_String] ) {
        m_String = new_string;
        [self buildLine];
        [self setNeedsDisplay:true];
    }
}

- (void) buildLine
{
    assert( m_String );
    const auto attrs = @{NSFontAttributeName: m_Font,
                         (NSString*)kCTForegroundColorFromContextAttributeName: @YES};
    NSAttributedString *as = [[NSAttributedString alloc] initWithString:m_String
                                                             attributes:attrs];
    
    if( m_Line )
        CFRelease( m_Line );
    m_Line = CTLineCreateWithAttributedString( (CFAttributedStringRef)as );
}

- (time_t) time
{
    return m_Time;
}

- (void) drawRect:(NSRect)dirtyRect
{
    if( auto rv = m_RowView ) {
        if( auto lv = rv.listView ) {
            const auto geometry = lv.geometry;
            const auto context = NSGraphicsContext.currentContext.CGContext;
            
            [rv.rowBackgroundColor set];
            NSRectFill(self.bounds);
            DrawTableVerticalSeparatorForView(self);            
            
            if( m_Line ) {
                CGContextSetFillColorWithColor( context, rv.rowTextColor.CGColor );
                CGContextSetTextPosition( context, geometry.LeftInset(), geometry.TextBaseLine() );
                CGContextSetTextDrawingMode( context, kCGTextFill );
                CTLineDraw(m_Line, context);
            }
        }
    }
}

- (void) buildPresentation
{
    self.font = CurrentTheme().FilePanelsListFont();
    [self setNeedsDisplay:true];
}

@end

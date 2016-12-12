#include <Utility/ByteCountFormatter.h>
#include "PanelListView.h"
#include "PanelListViewGeometry.h"
#include "PanelListViewRowView.h"
#include "PanelListViewSizeView.h"

static NSString* FileSizeToString(const VFSListingItem &_dirent, const PanelDataItemVolatileData &_vd, ByteCountFormatter::Type _format)
{
    if( _dirent.IsDir() ) {
        if( _vd.is_size_calculated() ) {
            return ByteCountFormatter::Instance().ToNSString(_vd.size, _format);
        }
        else {
            if(_dirent.IsDotDot())
                return NSLocalizedString(@"__MODERNPRESENTATION_UP_WORD", "Upper-level in directory, for English is 'Up'");
            else
                return NSLocalizedString(@"__MODERNPRESENTATION_FOLDER_WORD", "Folders dummy string when size is not available, for English is 'Folder'");
        }
    }
    else {
        return ByteCountFormatter::Instance().ToNSString(_dirent.Size(), _format);
    }
}

static NSParagraphStyle *ParagraphStyle( NSLineBreakMode _mode )
{
    static NSParagraphStyle *styles[3];
    static once_flag once;
    call_once(once, []{
        NSMutableParagraphStyle *p0 = [NSMutableParagraphStyle new];
        p0.alignment = NSTextAlignmentRight;
        p0.lineBreakMode = NSLineBreakByTruncatingHead;
        styles[0] = p0;
        
        NSMutableParagraphStyle *p1 = [NSMutableParagraphStyle new];
        p1.alignment = NSTextAlignmentRight;
        p1.lineBreakMode = NSLineBreakByTruncatingTail;
        styles[1] = p1;
        
        NSMutableParagraphStyle *p2 = [NSMutableParagraphStyle new];
        p2.alignment = NSTextAlignmentRight;
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

@implementation PanelListViewSizeView
{
    NSString        *m_String;
    NSDictionary    *m_TextAttributes;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_String = @"";
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

- (void) drawRect:(NSRect)dirtyRect
{    
    if( auto rv = objc_cast<PanelListViewRowView>(self.superview) ) {
        if( auto lv = rv.listView ) {
            const auto bounds = self.bounds;
            const auto geometry = lv.geometry;
            
            const auto context = NSGraphicsContext.currentContext.CGContext;
            rv.rowBackgroundDoubleColor.Set( context );
//            CGContextSetFillColorWithColor(context, rv.rowBackgroundColor.CGColor);
//            CGContextSetRGBFillColor
            CGContextFillRect(context, NSRectToCGRect(self.bounds));
            
            const auto text_rect = NSMakeRect(geometry.LeftInset(),
                                              geometry.TextBaseLine(),
                                              bounds.size.width -  geometry.LeftInset() - geometry.RightInset(),
                                              0);
            [m_String drawWithRect:text_rect
                           options:0
                        attributes:m_TextAttributes
                           context:nil];
        }
    }
}

static const auto g_ParagraphStyle = []{
    NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
    p.alignment = NSTextAlignmentRight;
    p.lineBreakMode = /*NSLineBreakByTruncatingMiddle*/NSLineBreakByClipping;
    return p;
}();

- (void) buildPresentation
{
    if( PanelListViewRowView *row_view = (PanelListViewRowView*)self.superview ) {
        if( auto item = row_view.item )
            m_String = FileSizeToString(item,
                                        row_view.vd,
                                        ByteCountFormatter::Type::Adaptive8);

        m_TextAttributes = @{NSFontAttributeName:row_view.listView.font,
                             NSForegroundColorAttributeName: row_view.rowTextColor,
                             NSParagraphStyleAttributeName: g_ParagraphStyle};
        
        [self setNeedsDisplay:true];
    }
}

@end

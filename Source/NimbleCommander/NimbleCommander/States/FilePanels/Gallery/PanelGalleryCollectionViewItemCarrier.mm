// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelGalleryCollectionViewItemCarrier.h"
#include "PanelGalleryCollectionViewItem.h"
#include "../PanelViewPresentationSettings.h"
#include <NimbleCommander/Core/Theming/Theme.h> // Evil!
#include <Base/algo.h>
#include <Base/CFPtr.h>

#include <fmt/format.h>
#include <CoreText/CoreText.h>

using namespace nc::panel;
using namespace nc::panel::gallery;

static NSParagraphStyle *ParagraphStyle(PanelViewFilenameTrimming _mode)
{
    static NSParagraphStyle *styles[3];
    static std::once_flag once;
    std::call_once(once, [] {
        NSMutableParagraphStyle *const p0 = [NSMutableParagraphStyle new];
        p0.alignment = NSTextAlignmentCenter;
        p0.lineBreakMode = NSLineBreakByTruncatingHead;
        p0.allowsDefaultTighteningForTruncation = true;
        styles[0] = p0;

        NSMutableParagraphStyle *const p1 = [NSMutableParagraphStyle new];
        p1.alignment = NSTextAlignmentCenter;
        p1.lineBreakMode = NSLineBreakByTruncatingTail;
        p1.allowsDefaultTighteningForTruncation = true;
        styles[1] = p1;

        NSMutableParagraphStyle *const p2 = [NSMutableParagraphStyle new];
        p2.alignment = NSTextAlignmentCenter;
        p2.lineBreakMode = NSLineBreakByTruncatingMiddle;
        p2.allowsDefaultTighteningForTruncation = true;
        styles[2] = p2;
    });

    switch( _mode ) {
        case PanelViewFilenameTrimming::Heading:
            return styles[0];
        case PanelViewFilenameTrimming::Trailing:
            return styles[1];
        case PanelViewFilenameTrimming::Middle:
            return styles[2];
        default:
            return nil;
    }
}

@implementation NCPanelGalleryCollectionViewItemCarrier {
    __weak NCPanelGalleryCollectionViewItem *m_Controller;
    NSImage *m_Icon;
    NSString *m_Filename;
    //    NSMutableAttributedString *m_AttrString;
    std::vector<NSMutableAttributedString *> m_AttrStrings;
    ItemLayout m_ItemLayout;
}

@synthesize controller = m_Controller;
@synthesize icon = m_Icon;
@synthesize filename = m_Filename;
@synthesize itemLayout = m_ItemLayout;

//@property(nonatomic, weak) NCPanelGalleryCollectionViewItem *controller;
//@property(nonatomic) NSImage *icon;
//@property(nonatomic) NSString *filename;
//@property(nonatomic) nc::panel::gallery::ItemLayout itemLayout;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        self.autoresizingMask = NSViewNotSizable;
        self.autoresizesSubviews = false;
        //        self.postsFrameChangedNotifications = false; // ???
        //        self.postsBoundsChangedNotifications = false; // ???
    }
    return self;
}

- (BOOL)isOpaque
{
    return true;
}

- (BOOL)wantsDefaultClipping
{
    return false;
}

- (void)drawRect:(NSRect) [[maybe_unused]] _dirty_rect
{
    //    if ( !m_Filename )
    //        return;
    //

    const auto bounds = self.bounds;
    const auto context = NSGraphicsContext.currentContext.CGContext;

    //    NSColor *background = NSColor.purpleColor; // ????????????????????????????
    NSColor *background = NSColor.grayColor; // ????????????????????????????

    CGContextSetFillColorWithColor(context, background.CGColor);
    CGContextFillRect(context, bounds);

    const auto icon_rect = NSMakeRect(m_ItemLayout.icon_left_margin,
                                      bounds.size.height - static_cast<double>(m_ItemLayout.icon_top_margin) -
                                          static_cast<double>(m_ItemLayout.icon_size),
                                      m_ItemLayout.icon_size,
                                      m_ItemLayout.icon_size);
    [m_Icon drawInRect:icon_rect
              fromRect:NSZeroRect
             operation:NSCompositingOperationSourceOver
              fraction:1.0
        respectFlipped:false
                 hints:nil];

    if( m_AttrStrings.empty() ) {
        [self buildTextAttributes];
    }

    const NSRect text_rect = [self calculateTextSegmentFromBounds:bounds];

    double current_y =
        text_rect.origin.y + text_rect.size.height - m_ItemLayout.font_height + m_ItemLayout.font_baseline;

    for( NSAttributedString *attr_str : m_AttrStrings ) {
        [attr_str drawWithRect:NSMakeRect(text_rect.origin.x, current_y, text_rect.size.width, 0)
                       options:0
                       context:nil];
        current_y -= m_ItemLayout.font_height;
    }

}

- (void)setFilename:(NSString *)_filename
{
    if( m_Filename == _filename )
        return;
    m_Filename = _filename;
    m_AttrStrings.clear();
    [self setNeedsDisplay:true];
}

- (NSRect)calculateTextSegmentFromBounds:(NSRect)_bounds
{
    const int origin_x = m_ItemLayout.text_left_margin;
    const int origin_y = m_ItemLayout.text_bottom_margin;
    const int width =
        static_cast<int>(_bounds.size.width) - m_ItemLayout.text_left_margin - m_ItemLayout.text_right_margin;
    const int height = m_ItemLayout.text_lines * m_ItemLayout.font_height;
    return NSMakeRect(origin_x, origin_y, width, height);
}

static std::vector<NSRange>
CutStringIntoWrappedAndTailSubstrings(NSAttributedString *_attr_string, double _width, size_t _max_lines)
{
    assert(_max_lines > 0);
    if( _max_lines == 1 ) {
        return {NSMakeRange(0, _attr_string.length)};
    }

    const nc::base::CFPtr<CTTypesetterRef> typesetter = nc::base::CFPtr<CTTypesetterRef>::adopt(
        CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)(_attr_string)));

    std::vector<NSRange> result;
    CFIndex start = 0;
    for( size_t line_idx = 0; line_idx < _max_lines - 1; ++line_idx ) {
        CFIndex count = CTTypesetterSuggestLineBreak(typesetter.get(), start, _width);
        if( count <= 0 ) {
            break;
        }
        result.push_back(NSMakeRange(static_cast<NSUInteger>(start), static_cast<NSUInteger>(count)));
        start += count;
    }

    const CFIndex length = static_cast<CFIndex>(_attr_string.length);
    if( start < length ) {
        result.push_back(NSMakeRange(static_cast<NSUInteger>(start), static_cast<NSUInteger>(length - start)));
    }

    return result;
}

- (void)buildTextAttributes
{
    static NSParagraphStyle *const breaking_paragraph_style = [] {
        NSMutableParagraphStyle *const p = [NSMutableParagraphStyle new];
        p.alignment = NSTextAlignmentCenter;
        p.lineBreakMode = NSLineBreakByWordWrapping;
        p.allowsDefaultTighteningForTruncation = true;
        return p;
    }();

    assert(m_Filename != nil);

    // Build a minimal set of attributes solely for typesetting
    NSDictionary *typesetting_attrs = @{
        NSFontAttributeName: nc::CurrentTheme().FilePanelsBriefFont(),
        NSParagraphStyleAttributeName: breaking_paragraph_style
    };

    // Split the filename into lines that fit within the available width
    NSMutableAttributedString *typesetting_attr_string =
        [[NSMutableAttributedString alloc] initWithString:m_Filename attributes:typesetting_attrs];
    const NSRect text_rect = [self calculateTextSegmentFromBounds:self.bounds];
    const std::vector<NSRange> substrings =
        CutStringIntoWrappedAndTailSubstrings(typesetting_attr_string, text_rect.size.width, m_ItemLayout.text_lines);

    const auto tm = GetCurrentFilenamesTrimmingMode();
    NSDictionary *attrs_2 = @{
        NSFontAttributeName: nc::CurrentTheme().FilePanelsBriefFont(),
        NSForegroundColorAttributeName: NSColor.blackColor,
        NSParagraphStyleAttributeName: ParagraphStyle(tm)
    };

    // TODO: QuickSearch
    //    if( !m_QSHighlight.empty() ) {
    //        const auto hl = m_QSHighlight.unpack();
    //        const auto fn_len = static_cast<size_t>(m_Filename.length);
    //        for( size_t i = 0; i != hl.count; ++i ) {
    //            if( hl.segments[i].offset < fn_len && hl.segments[i].offset + hl.segments[i].length <= fn_len ) {
    //                const auto range = NSMakeRange(hl.segments[i].offset, hl.segments[i].length);
    //                [m_AttrString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle)
    //                range:range];
    //            }
    //        }
    //    }

    m_AttrStrings.clear();

    for( NSRange range : substrings ) {
        m_AttrStrings.push_back([[NSMutableAttributedString alloc] initWithString:[m_Filename substringWithRange:range]
                                                                       attributes:attrs_2]);
    }
}

@end

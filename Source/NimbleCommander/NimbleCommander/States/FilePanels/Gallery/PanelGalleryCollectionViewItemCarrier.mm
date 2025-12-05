// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelGalleryCollectionViewItemCarrier.h"
#include "PanelGalleryCollectionViewItem.h"
#include "../PanelViewPresentationSettings.h"
#include <NimbleCommander/Core/Theming/Theme.h> // Evil!
#include <Base/algo.h>
#include <Base/CFPtr.h>
#include <boost/container/static_vector.hpp> // TODO: switch to std::inplace_vector once available

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
    NSColor *m_BackgroundColor;
    NSColor *m_FilenameColor;
    boost::container::static_vector<NSMutableAttributedString *, 4> m_AttrStrings;
    ItemLayout m_ItemLayout;
    nc::panel::data::QuickSearchHighlight m_QSHighlight;
}

@synthesize controller = m_Controller;
@synthesize icon = m_Icon;
@synthesize filename = m_Filename;
@synthesize itemLayout = m_ItemLayout;
@synthesize backgroundColor = m_BackgroundColor;
@synthesize filenameColor = m_FilenameColor;
@synthesize qsHighlight = m_QSHighlight;

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
    const auto bounds = self.bounds;
    const auto context = NSGraphicsContext.currentContext.CGContext;

    NSColor *background = m_BackgroundColor;

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

- (void)setBackgroundColor:(NSColor *)_background_color
{
    if( m_BackgroundColor == _background_color )
        return;
    m_BackgroundColor = _background_color;
    [self setNeedsDisplay:true];
}

- (void)setFilenameColor:(NSColor *)_filename_color
{
    if( m_FilenameColor == _filename_color )
        return;
    m_FilenameColor = _filename_color;
    m_AttrStrings.clear();
    [self setNeedsDisplay:true];
}

- (void)setQsHighlight:(nc::panel::data::QuickSearchHighlight)_qs_highlight
{
    if( m_QSHighlight == _qs_highlight )
        return;
    m_QSHighlight = _qs_highlight;
    m_AttrStrings.clear();
    [self setNeedsDisplay:true];
}

- (void)setIcon:(NSImage *)_icon
{
    if( m_Icon == _icon )
        return;
    m_Icon = _icon;
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

static boost::container::static_vector<NSRange, 4>
CutFilenameIntoWrappedAndTailSubstrings(NSAttributedString *_attr_string, double _width, size_t _max_lines)
{
    assert(_max_lines > 0 && _max_lines <= 4);
    if( _max_lines == 1 ) {
        return {NSMakeRange(0, _attr_string.length)};
    }

    const nc::base::CFPtr<CTTypesetterRef> typesetter = nc::base::CFPtr<CTTypesetterRef>::adopt(
        CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)(_attr_string)));

    boost::container::static_vector<NSRange, 4> result;
    long start = 0;
    for( size_t line_idx = 0; line_idx < _max_lines - 1; ++line_idx ) {
        const long count = CTTypesetterSuggestLineBreak(typesetter.get(), start, _width);
        if( count <= 0 ) {
            break;
        }
        result.push_back(NSMakeRange(static_cast<NSUInteger>(start), static_cast<NSUInteger>(count)));
        start += count;
    }

    const long length = static_cast<long>(_attr_string.length);
    if( start < length ) {
        result.push_back(NSMakeRange(static_cast<NSUInteger>(start), static_cast<NSUInteger>(length - start)));
    }

    // Check for a special case when the extension is split across 2 lines and could be rebalanced for better
    // readability
    if( result.size() >= 2 ) { // at least 2 lines to consider rebalancing
        const NSRange last_dot = [_attr_string.string rangeOfString:@"." options:NSBackwardsSearch];
        if( last_dot.location != NSNotFound &&                        // actual dot was found ...
            last_dot.location > 0 &&                                  // ... and it's something like an extension
            last_dot.location > result[result.size() - 2].location && // dot is on the previous to the last line
            last_dot.location < result[result.size() - 1].location    // dot is on the previous to the last line
        ) {
            // Check if after rebalancing the last line would still fit
            const long new_break = CTTypesetterSuggestLineBreak(typesetter.get(), last_dot.location, _width);
            if( (new_break + last_dot.location) == static_cast<NSUInteger>(length) ) {
                const long diff = result.back().location - last_dot.location;
                assert(diff > 0);
                result[result.size() - 2].length -= diff;
                result[result.size() - 1].location -= diff;
                result[result.size() - 1].length += diff;
            }
        }
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
        NSFontAttributeName: nc::CurrentTheme().FilePanelsGalleryFont(),
        NSParagraphStyleAttributeName: breaking_paragraph_style
    };

    // Split the filename into lines that fit within the available width
    NSMutableAttributedString *typesetting_attr_string =
        [[NSMutableAttributedString alloc] initWithString:m_Filename attributes:typesetting_attrs];
    const NSRect text_rect = [self calculateTextSegmentFromBounds:self.bounds];
    const boost::container::static_vector<NSRange, 4> substrings =
        CutFilenameIntoWrappedAndTailSubstrings(typesetting_attr_string, text_rect.size.width, m_ItemLayout.text_lines);

    // Build the final text attributes for rendering
    NSDictionary *final_attrs = @{
        NSFontAttributeName: nc::CurrentTheme().FilePanelsGalleryFont(),
        NSForegroundColorAttributeName: m_FilenameColor,
        NSParagraphStyleAttributeName: ParagraphStyle(GetCurrentFilenamesTrimmingMode())
    };

    m_AttrStrings.clear();

    const data::QuickSearchHighlight::Ranges qs_ranges = m_QSHighlight.unpack();

    for( NSRange range : substrings ) {
        NSMutableAttributedString *str =
            [[NSMutableAttributedString alloc] initWithString:[m_Filename substringWithRange:range]
                                                   attributes:final_attrs];

        // Apply QuickSearch underlining if there is one
        if( qs_ranges.count != 0 ) {
            // For every QS range, check if it intersects with the current substring range
            for( size_t i = 0; i != qs_ranges.count; ++i ) {
                const NSRange qs_range = NSMakeRange(qs_ranges.segments[i].offset, qs_ranges.segments[i].length);
                if( NSIntersectionRange(range, qs_range).length > 0 ) {
                    // There is an intersection, apply underline to the intersecting part
                    const NSRange intersection = NSIntersectionRange(range, qs_range);
                    const NSRange local_range =
                        NSMakeRange(intersection.location - range.location, intersection.length);
                    [str addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:local_range];
                }
            }
        }

        m_AttrStrings.push_back(str);
    }
}

@end

// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#import "NCPanelBreadcrumbsView.h"
#import "NCPanelPathSegment.h"
#include <Panel/Log.h>
#include <algorithm>
#include <cmath>

static NSString *const kSep = @" › ";

/// Padding around segment text for the link hover box (CSS-like padding on the anchor).
static const CGFloat kBreadcrumbLinkPadX = 1.5;
/// Vertical: slightly less above than below so the pill looks even around ink (glyph bounds still read top-heavy).
static const CGFloat kBreadcrumbLinkPadYTop = 0.3;
static const CGFloat kBreadcrumbLinkPadYBottom = 0.7;
/// Inset of the path bar content clip from the bar edges (parent padding before overflow:hidden).
static const CGFloat kBreadcrumbBarContentInsetY = 2.;

/// Hover fill clip: normally inset from the bar for breathing room. When the padded link extends past that
/// content box (large font / tall line), clip the hover to the full bar so the pill meets the bar edge with no gap.
static NSRect NCBreadcrumbHoverClipRect(NSRect bounds, NSRect paddedLinkRect) noexcept
{
    const NSRect content = NSInsetRect(bounds, 0., kBreadcrumbBarContentInsetY);
    const CGFloat cminY = NSMinY(content);
    const CGFloat cmaxY = NSMaxY(content);
    const CGFloat lminY = NSMinY(paddedLinkRect);
    const CGFloat lmaxY = NSMaxY(paddedLinkRect);
    if( lminY < cminY - 0.5 || lmaxY > cmaxY + 0.5 )
        return bounds;
    return content;
}

static NSRect NCBreadcrumbPaddedLinkRectFromHoverBase(NSRect hoverBase) noexcept
{
    return NSMakeRect(hoverBase.origin.x - kBreadcrumbLinkPadX,
                      hoverBase.origin.y - kBreadcrumbLinkPadYTop,
                      hoverBase.size.width + 2. * kBreadcrumbLinkPadX,
                      hoverBase.size.height + kBreadcrumbLinkPadYTop + kBreadcrumbLinkPadYBottom);
}

static void NCBreadcrumbTraceHoverLayout(NSString *titleSnippet,
                                         NSInteger segmentIndex,
                                         CGFloat xBase,
                                         NSRect hoverBaseRect,
                                         NSRect linkRect,
                                         CGFloat stripH,
                                         NSRect bounds) noexcept
{
    NSString *const t = titleSnippet.length > 24 ? [titleSnippet substringToIndex:24] : titleSnippet;
    const char *const ut = t.UTF8String;
    nc::panel::Log::Trace("[PathBarHover] layout seg={} title=\"{}\" xBase={:.3f} hoverBase=({:.3f},{:.3f},{:.3f},{:.3f}) "
                          "linkRect=({:.3f},{:.3f},{:.3f},{:.3f}) padX={:.3f} padYTop={:.3f} padYBottom={:.3f} barInsetY={:.3f} "
                          "stripH={:.3f} bounds=({:.3f},{:.3f},{:.3f},{:.3f})",
                          static_cast<int>(segmentIndex),
                          ut ? ut : "",
                          xBase,
                          hoverBaseRect.origin.x,
                          hoverBaseRect.origin.y,
                          hoverBaseRect.size.width,
                          hoverBaseRect.size.height,
                          linkRect.origin.x,
                          linkRect.origin.y,
                          linkRect.size.width,
                          linkRect.size.height,
                          kBreadcrumbLinkPadX,
                          kBreadcrumbLinkPadYTop,
                          kBreadcrumbLinkPadYBottom,
                          kBreadcrumbBarContentInsetY,
                          stripH,
                          bounds.origin.x,
                          bounds.origin.y,
                          bounds.size.width,
                          bounds.size.height);
}

static void NCBreadcrumbTraceHoverDraw(NSInteger segmentIndex,
                                         NSString *titleSnippet,
                                         CGFloat x,
                                         CGFloat yContainer,
                                         NSRect usedTitle,
                                         NSRect hoverBaseRect,
                                         NSRect linkRect,
                                         NSRect clipRect,
                                         NSRect bounds,
                                         CGFloat stripH,
                                         NSRect layoutStoredLinkRect,
                                         BOOL haveLayoutRect) noexcept
{
    NSString *const t = titleSnippet.length > 24 ? [titleSnippet substringToIndex:24] : titleSnippet;
    const char *const ut = t.UTF8String;
    NSRect inter = NSZeroRect;
    if( haveLayoutRect )
        inter = NSIntersectionRect(linkRect, clipRect);
    nc::panel::Log::Trace("[PathBarHover] draw seg={} title=\"{}\" x={:.3f} yCont={:.3f} "
                          "used=({:.3f},{:.3f},{:.3f},{:.3f}) hoverBase=({:.3f},{:.3f},{:.3f},{:.3f}) "
                          "linkRect=({:.3f},{:.3f},{:.3f},{:.3f}) clipRect=({:.3f},{:.3f},{:.3f},{:.3f}) "
                          "stripH={:.3f} bounds=({:.3f},{:.3f},{:.3f},{:.3f})",
                          static_cast<int>(segmentIndex),
                          ut ? ut : "",
                          x,
                          yContainer,
                          usedTitle.origin.x,
                          usedTitle.origin.y,
                          usedTitle.size.width,
                          usedTitle.size.height,
                          hoverBaseRect.origin.x,
                          hoverBaseRect.origin.y,
                          hoverBaseRect.size.width,
                          hoverBaseRect.size.height,
                          linkRect.origin.x,
                          linkRect.origin.y,
                          linkRect.size.width,
                          linkRect.size.height,
                          clipRect.origin.x,
                          clipRect.origin.y,
                          clipRect.size.width,
                          clipRect.size.height,
                          stripH,
                          bounds.origin.x,
                          bounds.origin.y,
                          bounds.size.width,
                          bounds.size.height);
    if( haveLayoutRect ) {
        const CGFloat dx = linkRect.origin.x - layoutStoredLinkRect.origin.x;
        const CGFloat dy = linkRect.origin.y - layoutStoredLinkRect.origin.y;
        const CGFloat dw = linkRect.size.width - layoutStoredLinkRect.size.width;
        const CGFloat dh = linkRect.size.height - layoutStoredLinkRect.size.height;
        nc::panel::Log::Trace("[PathBarHover] draw vs layout linkRect d.origin=({:.3f},{:.3f}) d.size=({:.3f},{:.3f}) "
                              "layoutStored=({:.3f},{:.3f},{:.3f},{:.3f}) link_inter_clip=({:.3f},{:.3f},{:.3f},{:.3f})",
                              dx,
                              dy,
                              dw,
                              dh,
                              layoutStoredLinkRect.origin.x,
                              layoutStoredLinkRect.origin.y,
                              layoutStoredLinkRect.size.width,
                              layoutStoredLinkRect.size.height,
                              inter.origin.x,
                              inter.origin.y,
                              inter.size.width,
                              inter.size.height);
    }
    else {
        nc::panel::Log::Trace("[PathBarHover] draw vs layout no stored linkRect for this segment index");
    }
}

CGFloat NCPanelPathBarOpticalShiftUp(NSFont *font, CGFloat lineBoxHeight)
{
    if( font == nil || lineBoxHeight <= 0. )
        return 0.;
    CGFloat cap = font.capHeight;
    if( cap < 1. )
        cap = MAX(font.xHeight, 1.);
    if( lineBoxHeight <= cap )
        return 0.;
    // Linear: excess height above cap is mostly padding; nudge the line box up (smaller y in flipped coords).
    return (lineBoxHeight - cap) * 0.25;
}

CGFloat NCPanelPathBarContainerOriginYForLine(NSFont *font, CGFloat stripH, CGFloat usedH, CGFloat usedOriginY)
{
    if( usedH <= 0. )
        return 0.;
    const CGFloat geometric = (stripH - usedH) * 0.5 - usedOriginY;
    const CGFloat optical = NCPanelPathBarOpticalShiftUp(font, usedH);
    CGFloat y = geometric - optical;
    if( usedH > stripH ) {
        const CGFloat lo = stripH - usedH - usedOriginY;
        const CGFloat hi = -usedOriginY;
        if( y < lo )
            y = lo;
        else if( y > hi )
            y = hi;
    }
    return y;
}

/// Points per pixel for this view (1 on non-Retina, 2 on typical Retina). Used to snap coordinates to the device pixel grid.
static CGFloat NCBreadcrumbViewBackingScale(NSView *view) noexcept
{
    NSWindow *const win = view.window;
    CGFloat s = win != nil ? win.backingScaleFactor : 0.;
    if( s <= 0. && win != nil && win.screen != nil )
        s = win.screen.backingScaleFactor;
    if( s <= 0. )
        s = NSScreen.mainScreen.backingScaleFactor;
    if( s <= 0. )
        s = 2.;
    return s;
}

static inline CGFloat NCBreadcrumbAlignToPixelGrid(CGFloat value, CGFloat scale) noexcept
{
    return std::round(value * scale) / scale;
}

/// Typographic bounds from the same TextKit stack that lays out drawn strings (`lineFragmentPadding` 0 matches tight
/// single-line `drawInRect:` usage). `usedRectForTextContainer:` is the standard way to get the glyph enclosure, not a
/// heuristic on `capHeight`.
static NSRect NCBreadcrumbTextKitUsedRect(NSString *text, NSDictionary *attrs, NSFont *fallbackFont) noexcept
{
    if( text.length == 0 || attrs == nil )
        return NSZeroRect;
    NSDictionary *effectiveAttrs = attrs;
    NSMutableDictionary *withFont = nil;
    if( [attrs objectForKey:NSFontAttributeName] == nil && fallbackFont != nil ) {
        withFont = [attrs mutableCopy];
        withFont[NSFontAttributeName] = fallbackFont;
        effectiveAttrs = withFont;
    }
    NSTextStorage *const ts = [[NSTextStorage alloc] initWithString:text attributes:effectiveAttrs];
    NSLayoutManager *const lm = [[NSLayoutManager alloc] init];
    NSTextContainer *const tc = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
    tc.lineFragmentPadding = 0.;
    [lm addTextContainer:tc];
    [ts addLayoutManager:lm];
    (void)[lm glyphRangeForTextContainer:tc];
    return [lm usedRectForTextContainer:tc];
}

static inline NSSize NCBreadcrumbTextKitUsedSize(NSString *text, NSDictionary *attrs, NSFont *fallbackFont) noexcept
{
    return NCBreadcrumbTextKitUsedRect(text, attrs, fallbackFont).size;
}

/// Vertical text-container origin: shared with `NCPanelPathBarContainerOriginYForLine`, then pixel-aligned.
static CGFloat NCBreadcrumbLineTopYForUsedRect(NSView *view, CGFloat stripH, NSRect used, NSFont *_Nullable font) noexcept
{
    const CGFloat usedH = NSHeight(used);
    if( usedH <= 0. )
        return 0.;
    const CGFloat y = NCPanelPathBarContainerOriginYForLine(font, stripH, usedH, used.origin.y);
    const CGFloat scale = NCBreadcrumbViewBackingScale(view);
    return NCBreadcrumbAlignToPixelGrid(y, scale);
}

/// Nudge hover base down (flipped coords) so less empty band sits above ink; used for line box and glyph union.
static NSRect NCBreadcrumbOpticalTrimHoverBaseTop(NSRect hb, NSFont *_Nullable metricsFont) noexcept
{
    if( metricsFont == nil || hb.size.height <= 1. )
        return hb;
    const CGFloat trim = std::clamp(metricsFont.pointSize * 0.0625,
                                    0.,
                                    std::min(CGFloat(1.25), hb.size.height * CGFloat(0.28)));
    hb.origin.y += trim;
    hb.size.height -= trim;
    return hb;
}

/// Segment hit/hover base: full line width (comfortable target), vertical extent from glyph bounds so padding is even
/// around ink (line-box height looks top-heavy vs visible text).
static NSRect NCBreadcrumbSegmentLinkBaseRectInView(NSString *text,
                                                    NSDictionary *attrs,
                                                    NSFont *fallbackFont,
                                                    NSView *view,
                                                    CGFloat x,
                                                    CGFloat stripH) noexcept
{
    if( text.length == 0 || attrs == nil )
        return NSZeroRect;
    NSDictionary *effectiveAttrs = attrs;
    NSMutableDictionary *withFont = nil;
    if( [attrs objectForKey:NSFontAttributeName] == nil && fallbackFont != nil ) {
        withFont = [attrs mutableCopy];
        withFont[NSFontAttributeName] = fallbackFont;
        effectiveAttrs = withFont;
    }
    NSTextStorage *const ts = [[NSTextStorage alloc] initWithString:text attributes:effectiveAttrs];
    NSLayoutManager *const lm = [[NSLayoutManager alloc] init];
    NSTextContainer *const tc = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
    tc.lineFragmentPadding = 0.;
    [lm addTextContainer:tc];
    [ts addLayoutManager:lm];
    (void)[lm glyphRangeForTextContainer:tc];
    [lm ensureLayoutForTextContainer:tc];
    const NSRect used = [lm usedRectForTextContainer:tc];
    NSFont *const metricsFont = [effectiveAttrs objectForKey:NSFontAttributeName] ?: fallbackFont;
    const CGFloat yContainer = NCBreadcrumbLineTopYForUsedRect(view, stripH, used, metricsFont);
    const NSRect line =
        NSMakeRect(x + used.origin.x, yContainer + used.origin.y, used.size.width, used.size.height);
    const NSRange glyphRange = [lm glyphRangeForTextContainer:tc];
    if( glyphRange.length == 0 )
        return NCBreadcrumbOpticalTrimHoverBaseTop(line, metricsFont);
    const NSRect gb = [lm boundingRectForGlyphRange:glyphRange inTextContainer:tc];
    if( gb.size.height < 0.5 )
        return NCBreadcrumbOpticalTrimHoverBaseTop(line, metricsFont);
    NSRect hb = NSMakeRect(line.origin.x, yContainer + gb.origin.y, line.size.width, gb.size.height);
    return NCBreadcrumbOpticalTrimHoverBaseTop(hb, metricsFont);
}

/// TextKit metrics + `NSAttributedString drawWithRect:options:` clipped to the strip.
static NSRect NCBreadcrumbTextKitDrawLine(NSString *text,
                                         NSDictionary *attrs,
                                         NSFont *fallbackFont,
                                         NSView *view,
                                         CGFloat x,
                                         CGFloat stripH,
                                         CGFloat *outContainerOriginY) noexcept
{
    if( outContainerOriginY )
        *outContainerOriginY = 0.;
    if( text.length == 0 || attrs == nil )
        return NSZeroRect;
    NSDictionary *effectiveAttrs = attrs;
    NSMutableDictionary *withFont = nil;
    if( [attrs objectForKey:NSFontAttributeName] == nil && fallbackFont != nil ) {
        withFont = [attrs mutableCopy];
        withFont[NSFontAttributeName] = fallbackFont;
        effectiveAttrs = withFont;
    }
    NSTextStorage *const ts = [[NSTextStorage alloc] initWithString:text attributes:effectiveAttrs];
    NSLayoutManager *const lm = [[NSLayoutManager alloc] init];
    NSTextContainer *const tc = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
    tc.lineFragmentPadding = 0.;
    [lm addTextContainer:tc];
    [ts addLayoutManager:lm];
    (void)[lm glyphRangeForTextContainer:tc];
    [lm ensureLayoutForTextContainer:tc];
    const NSRect used = [lm usedRectForTextContainer:tc];
    NSFont *const metricsFont = [effectiveAttrs objectForKey:NSFontAttributeName] ?: fallbackFont;
    const CGFloat yContainer = NCBreadcrumbLineTopYForUsedRect(view, stripH, used, metricsFont);
    if( outContainerOriginY )
        *outContainerOriginY = yContainer;
    const NSRect lineRect =
        NSMakeRect(x + used.origin.x, yContainer + used.origin.y, used.size.width, used.size.height);
    {
        NSFont *const traceFont = [effectiveAttrs objectForKey:NSFontAttributeName];
        const CGFloat usedH = NSHeight(used);
        const CGFloat midY = yContainer + used.origin.y + usedH * 0.5;
        const CGFloat stripMid = stripH * 0.5;
        NSString *const prev = text.length > 32 ? [text substringToIndex:32] : text;
        const char *const ut = prev.UTF8String;
        const CGFloat defLH = traceFont != nil ? [lm defaultLineHeightForFont:traceFont] : 0.;
        const CGFloat opticalRaw = NCPanelPathBarOpticalShiftUp(traceFont, usedH);
        nc::panel::Log::Trace("[PathBar] \"{}\" stripH={:.3f} viewWH={:.1f}x{:.1f} "
                              "used.origin=({:.3f},{:.3f}) used.size={:.3f}x{:.3f} "
                              "yContainer={:.3f} lineRect.y={:.3f} lineRect.h={:.3f} "
                              "fontPt={:.1f} defaultLineH={:.3f} opticalRaw={:.3f} midY={:.3f} stripMid={:.3f} dMid={:.3f}",
                              ut ? ut : "",
                              stripH,
                              NSWidth(view.bounds),
                              NSHeight(view.bounds),
                              used.origin.x,
                              used.origin.y,
                              used.size.width,
                              used.size.height,
                              yContainer,
                              lineRect.origin.y,
                              lineRect.size.height,
                              traceFont != nil ? traceFont.pointSize : 0.,
                              defLH,
                              opticalRaw,
                              midY,
                              stripMid,
                              midY - stripMid);
    }
    NSAttributedString *const drawn = [[NSAttributedString alloc] initWithString:text attributes:effectiveAttrs];
    NSGraphicsContext *const gctx = NSGraphicsContext.currentContext;
    [gctx saveGraphicsState];
    [[NSBezierPath bezierPathWithRect:NSMakeRect(0., 0., NSWidth(view.bounds), stripH)] addClip];
    [drawn drawWithRect:lineRect
                options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesDeviceMetrics)
                  context:nil];
    [gctx restoreGraphicsState];
    return used;
}

@implementation NCPanelBreadcrumbsView {
    /// Padded text line rects in view coords (link hit / hover), aligned with `m_TitleSegmentIndices`.
    NSMutableArray<NSValue *> *m_SegmentLinkRects;
    NSMutableArray<NSNumber *> *m_TitleSegmentIndices;
    NSInteger m_LayoutStartIndex;
    CGFloat m_LeadingEllipsisWidth;
    CGFloat m_ContentOriginX;
}

@synthesize crumbDelegate = _crumbDelegate;
@synthesize segments = _segments;
@synthesize hoveredSegmentIndex = _hoveredSegmentIndex;
@synthesize crumbFont = _crumbFont;
@synthesize textColor = _textColor;
@synthesize linkColor = _linkColor;
@synthesize separatorColor = _separatorColor;
@synthesize hoverFillColor = _hoverFillColor;
@synthesize menuForEventBlock = _menuForEventBlock;

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_SegmentLinkRects = [NSMutableArray array];
        m_TitleSegmentIndices = [NSMutableArray array];
        self.hoveredSegmentIndex = -1;
        m_LayoutStartIndex = 0;
        m_LeadingEllipsisWidth = 0;
        m_ContentOriginX = 0;
    }
    return self;
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)setSegments:(NSArray<NCPanelPathSegment *> *)segments
{
    _segments = [segments copy];
    [self rebuildLayout];
    [self setNeedsDisplay:YES];
}

- (NSDictionary *)titleAttributesForSegment:(NCPanelPathSegment *)seg
{
    NSFont *const font = self.crumbFont ?: [NSFont systemFontOfSize:13];
    if( seg.navigatePOSIXPath.length && !seg.isCurrentDirectory )
        return @{NSFontAttributeName: font, NSForegroundColorAttributeName: self.linkColor ?: NSColor.linkColor};
    return @{NSFontAttributeName: font, NSForegroundColorAttributeName: self.textColor ?: NSColor.textColor};
}

- (NSDictionary *)separatorAttributes
{
    return @{
        NSFontAttributeName: self.crumbFont ?: [NSFont systemFontOfSize:13],
        NSForegroundColorAttributeName: self.separatorColor ?: [NSColor secondaryLabelColor],
    };
}

- (CGFloat)measureTotalWidthFromStartIndex:(NSInteger)start includeLeadingEllipsis:(BOOL)ell
    segs:(NSArray<NCPanelPathSegment *> *)segments
    pad:(CGFloat)pad
{
    NSFont *const font = self.crumbFont ?: [NSFont systemFontOfSize:13.];
    NSDictionary *const sepAttr = [self separatorAttributes];
    const NSSize sepSize = NCBreadcrumbTextKitUsedSize(kSep, sepAttr, font);

    CGFloat w = 2. * pad;
    if( ell ) {
        w += NCBreadcrumbTextKitUsedSize(@"… ", @{NSFontAttributeName: font}, font).width;
    }
    for( NSInteger i = start; i < static_cast<NSInteger>(segments.count); ++i ) {
        NCPanelPathSegment *const s = segments[static_cast<size_t>(i)];
        if( s.title.length == 0 )
            continue;
        NSDictionary *const a = [self titleAttributesForSegment:s];
        w += NCBreadcrumbTextKitUsedSize(s.title, a, font).width;
        if( i < static_cast<NSInteger>(segments.count) - 1 )
            w += sepSize.width;
    }
    return w;
}

/// Width of ellipsis + visible titles and separators only (no side padding), for centering.
- (CGFloat)visibleTrailWidthFromStartIndex:(NSInteger)start segs:(NSArray<NCPanelPathSegment *> *)segments
{
    NSFont *const font = self.crumbFont ?: [NSFont systemFontOfSize:13.];
    NSDictionary *const sepAttr = [self separatorAttributes];
    const NSSize sepSize = NCBreadcrumbTextKitUsedSize(kSep, sepAttr, font);
    CGFloat w = 0.;
    if( start > 0 )
        w += NCBreadcrumbTextKitUsedSize(@"… ", @{NSFontAttributeName: font}, font).width;
    for( NSInteger i = start; i < static_cast<NSInteger>(segments.count); ++i ) {
        NCPanelPathSegment *const s = segments[static_cast<size_t>(i)];
        if( s.title.length == 0 )
            continue;
        if( i > start )
            w += sepSize.width;
        NSDictionary *const a = [self titleAttributesForSegment:s];
        w += NCBreadcrumbTextKitUsedSize(s.title, a, font).width;
    }
    return w;
}

- (void)rebuildLayout
{
    [m_SegmentLinkRects removeAllObjects];
    [m_TitleSegmentIndices removeAllObjects];
    m_LayoutStartIndex = 0;
    m_LeadingEllipsisWidth = 0;
    m_ContentOriginX = 0.;

    NSArray<NCPanelPathSegment *> *const segs = self.segments;
    if( segs.count == 0 || self.bounds.size.width < 8 )
        return;

    const CGFloat pad = 6.;
    const CGFloat maxW = std::max(0., NSWidth(self.bounds) - 2 * pad);
    NSFont *const font = self.crumbFont ?: [NSFont systemFontOfSize:13.];

    NSInteger start = 0;
    while( start < static_cast<NSInteger>(segs.count) ) {
        const CGFloat tw = [self measureTotalWidthFromStartIndex:start
                                        includeLeadingEllipsis:(start > 0)
                                                            segs:segs
                                                             pad:pad];
        if( tw <= maxW )
            break;
        ++start;
    }
    m_LayoutStartIndex = start;
    if( start > 0 )
        m_LeadingEllipsisWidth = NCBreadcrumbTextKitUsedSize(@"… ", @{NSFontAttributeName: font}, font).width;

    const CGFloat trailW = [self visibleTrailWidthFromStartIndex:start segs:segs];
    const CGFloat boundsW = NSWidth(self.bounds);
    const CGFloat scale = NCBreadcrumbViewBackingScale(self);
    if( start > 0 ) {
        // Truncated: keep trail aligned to the leading padding (Finder-style).
        m_ContentOriginX = NCBreadcrumbAlignToPixelGrid(pad, scale);
    }
    else {
        // Full path fits: center the trail horizontally, snapped to the pixel grid.
        m_ContentOriginX = NCBreadcrumbAlignToPixelGrid(std::max(0., (boundsW - trailW) * 0.5), scale);
    }

    NSDictionary *const sepAttr = [self separatorAttributes];
    const NSSize sepSize = NCBreadcrumbTextKitUsedSize(kSep, sepAttr, font);
    const CGFloat stripH = NSHeight(self.bounds);

    CGFloat x = m_ContentOriginX;
    if( start > 0 )
        x += m_LeadingEllipsisWidth;

    for( NSInteger i = start; i < static_cast<NSInteger>(segs.count); ++i ) {
        NCPanelPathSegment *const s = segs[static_cast<size_t>(i)];
        if( s.title.length == 0 )
            continue;
        if( i > start )
            x += sepSize.width;
        NSDictionary *const a = [self titleAttributesForSegment:s];
        const NSSize ts = NCBreadcrumbTextKitUsedSize(s.title, a, font);
        const NSRect hoverBase = NCBreadcrumbSegmentLinkBaseRectInView(s.title, a, font, self, x, stripH);
        const NSRect linkRect = NCBreadcrumbPaddedLinkRectFromHoverBase(hoverBase);
        NCBreadcrumbTraceHoverLayout(s.title, i, x, hoverBase, linkRect, stripH, self.bounds);
        [m_SegmentLinkRects addObject:[NSValue valueWithRect:linkRect]];
        [m_TitleSegmentIndices addObject:@(i)];
        x += ts.width;
    }
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self rebuildLayout];
}

- (void)layout
{
    [super layout];
    [self rebuildLayout];
}

- (NSInteger)segmentIndexAtPoint:(NSPoint)p
{
    for( NSUInteger i = 0; i < m_SegmentLinkRects.count; ++i ) {
        const NSRect r = [m_SegmentLinkRects[i] rectValue];
        if( NSPointInRect(p, r) )
            return [m_TitleSegmentIndices[i] integerValue];
    }
    return -1;
}

- (nullable NSString *)posixPathAtViewPoint:(NSPoint)p fallbackPOSIXPath:(nullable NSString *)fallback plainPath:(nullable NSString *)plain
{
    if( self.segments.count == 0 )
        return plain.length ? plain : nil;
    const NSInteger idx = [self segmentIndexAtPoint:p];
    if( idx < 0 )
        return fallback.length ? fallback : (plain.length ? plain : nil);
    NCPanelPathSegment *const s = self.segments[static_cast<size_t>(idx)];
    if( s.navigatePOSIXPath.length )
        return s.navigatePOSIXPath;
    if( s.isCurrentDirectory )
        return fallback.length ? fallback : nil;
    return fallback.length ? fallback : plain;
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    if( self.segments.count == 0 || NSWidth(self.bounds) < 4 )
        return;

    const NSInteger start = m_LayoutStartIndex;
    NSDictionary *const sepAttr = [self separatorAttributes];
    NSFont *const font = self.crumbFont ?: [NSFont systemFontOfSize:13.];
    const NSSize sepSize = NCBreadcrumbTextKitUsedSize(kSep, sepAttr, font);
    const CGFloat stripH = NSHeight(self.bounds);

    CGFloat x = m_ContentOriginX;
    if( start > 0 ) {
        NSDictionary *ellAttr = @{NSFontAttributeName: font, NSForegroundColorAttributeName: self.textColor ?: NSColor.textColor};
        NSString *const ell = @"… ";
        CGFloat yEll = 0.;
        const NSRect usedEll = NCBreadcrumbTextKitDrawLine(ell, ellAttr, font, self, x, stripH, &yEll);
        x += usedEll.size.width;
    }

    for( NSInteger i = start; i < static_cast<NSInteger>(self.segments.count); ++i ) {
        NCPanelPathSegment *const s = self.segments[static_cast<size_t>(i)];
        if( s.title.length == 0 )
            continue;
        if( i > start ) {
            CGFloat ySep = 0.;
            (void)NCBreadcrumbTextKitDrawLine(kSep, sepAttr, font, self, x, stripH, &ySep);
            x += sepSize.width;
        }
        NSDictionary *const a = [self titleAttributesForSegment:s];
        CGFloat y = 0.;
        const NSRect usedTitle = NCBreadcrumbTextKitDrawLine(s.title, a, font, self, x, stripH, &y);
        if( self.hoveredSegmentIndex == i && self.hoverFillColor && self.hoverFillColor != NSColor.clearColor ) {
            const NSRect hoverBase = NCBreadcrumbSegmentLinkBaseRectInView(s.title, a, font, self, x, stripH);
            NSRect hr = NCBreadcrumbPaddedLinkRectFromHoverBase(hoverBase);
            const NSRect clipRect = NCBreadcrumbHoverClipRect(self.bounds, hr);
            NSRect layoutStoredLink = NSZeroRect;
            BOOL haveLayoutLink = NO;
            for( NSUInteger k = 0; k < m_TitleSegmentIndices.count; ++k ) {
                if( [m_TitleSegmentIndices[k] integerValue] == i ) {
                    layoutStoredLink = [m_SegmentLinkRects[k] rectValue];
                    haveLayoutLink = YES;
                    break;
                }
            }
            NCBreadcrumbTraceHoverDraw(i,
                                       s.title,
                                       x,
                                       y,
                                       usedTitle,
                                       hoverBase,
                                       hr,
                                       clipRect,
                                       self.bounds,
                                       stripH,
                                       layoutStoredLink,
                                       haveLayoutLink);
            NSGraphicsContext *const gctx = NSGraphicsContext.currentContext;
            [gctx saveGraphicsState];
            [[NSBezierPath bezierPathWithRect:clipRect] addClip];
            if( hr.size.width >= 1. && hr.size.height >= 0.5 ) {
                [self.hoverFillColor setFill];
                [[NSBezierPath bezierPathWithRoundedRect:hr xRadius:4 yRadius:4] fill];
            }
            [gctx restoreGraphicsState];
        }
        x += usedTitle.size.width;
    }
}

- (void)updateTrackingAreas
{
    [super updateTrackingAreas];
    for( NSTrackingArea *ta in [self.trackingAreas copy] )
        if( ta.owner == self )
            [self removeTrackingArea:ta];
    if( self.bounds.size.width > 1 && self.bounds.size.height > 1 ) {
        NSTrackingArea *const ta = [[NSTrackingArea alloc]
            initWithRect:self.bounds
                 options:NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow
                   owner:self
                userInfo:nil];
        [self addTrackingArea:ta];
    }
}

- (void)mouseMoved:(NSEvent *)event
{
    const NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    const NSInteger idx = [self segmentIndexAtPoint:p];
    if( idx != self.hoveredSegmentIndex ) {
        nc::panel::Log::Trace("[PathBarHover] mouse p=({:.3f},{:.3f}) hitSeg={} prevHoverSeg={}",
                              p.x,
                              p.y,
                              static_cast<int>(idx),
                              static_cast<int>(self.hoveredSegmentIndex));
        self.hoveredSegmentIndex = idx;
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseExited:(NSEvent *)event
{
    (void)event;
    self.hoveredSegmentIndex = -1;
    [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)event
{
    if( !self.crumbDelegate ) {
        [super mouseDown:event];
        return;
    }

    if( event.clickCount >= 2 ) {
        if( [self.crumbDelegate respondsToSelector:@selector(breadcrumbsViewDidRequestFullPathEdit:)] )
            [self.crumbDelegate breadcrumbsViewDidRequestFullPathEdit:self];
        return;
    }
    const NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    const NSInteger idx = [self segmentIndexAtPoint:p];
    if( idx < 0 )
        return;
    NCPanelPathSegment *const s = self.segments[static_cast<size_t>(idx)];
    if( s.navigatePOSIXPath.length > 0 ) {
        if( [self.crumbDelegate respondsToSelector:@selector(breadcrumbsView:didActivatePOSIXPath:)] )
            [self.crumbDelegate breadcrumbsView:self didActivatePOSIXPath:s.navigatePOSIXPath];
    }
    else if( s.isCurrentDirectory ) {
        if( [self.crumbDelegate respondsToSelector:@selector(breadcrumbsViewDidActivateCurrentSegment:)] )
            [self.crumbDelegate breadcrumbsViewDidActivateCurrentSegment:self];
    }
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
    if( self.menuForEventBlock ) {
        NSMenu *const m = self.menuForEventBlock(event);
        if( m )
            return m;
    }
    return [super menuForEvent:event];
}

@end

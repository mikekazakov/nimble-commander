// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#import "NCPanelBreadcrumbsView.h"
#include "NCPanelPathBarPresentation.h"
#include <Panel/Log.h>
#include <Utility/ObjCpp.h>
#include <algorithm>
#include <cmath>
#include <optional>
#include <string>

static NSString *const kSep = @"›";

static std::optional<std::string> NCBreadcrumbOptionalUTF8(NSString *_Nullable s) noexcept
{
    if( s.length == 0 )
        return std::nullopt;
    const char *const u = s.UTF8String;
    if( !u )
        return std::nullopt;
    return std::string{u};
}

static NSString *NCBreadcrumbLabel(const nc::panel::PanelHeaderBreadcrumb &breadcrumb) noexcept
{
    return breadcrumb.label ?: @"";
}

static NSString *NCBreadcrumbNavigatePath(const nc::panel::PanelHeaderBreadcrumb &breadcrumb) noexcept
{
    if( !breadcrumb.navigate_to_vfs_path.has_value() || breadcrumb.navigate_to_vfs_path->empty() )
        return @"";
    return [NSString stringWithUTF8String:breadcrumb.navigate_to_vfs_path->c_str()] ?: @"";
}

static NSRect NCBreadcrumbPaddedLinkRect(NSRect hoverBase, CGFloat padX, CGFloat padYTop, CGFloat padYBottom) noexcept
{
    return NSMakeRect(hoverBase.origin.x - padX,
                      hoverBase.origin.y - padYTop,
                      hoverBase.size.width + 2. * padX,
                      hoverBase.size.height + padYTop + padYBottom);
}

/// Extra horizontal/vertical expansion applied to stored link rects during hit testing so narrow
/// glyphs and separator gaps remain easy to click. Values are empirical: ~2pts at 13pt, scaling
/// gently with font size. Vertical slop is small because the header row already fills the strip.
static CGFloat NCBreadcrumbHitTestHorizontalSlop(NSFont *font) noexcept
{
    const CGFloat ps = font != nil ? font.pointSize : 13.;
    return std::max<CGFloat>(3., std::floor(ps * 0.22));
}

static CGFloat NCBreadcrumbHitTestVerticalSlop(NSFont *font) noexcept
{
    const CGFloat ps = font != nil ? font.pointSize : 13.;
    return std::max<CGFloat>(1., std::floor(ps * 0.08));
}

static void NCBreadcrumbTraceHoverLayout(NSString *titleSnippet,
                                         NSInteger segmentIndex,
                                         CGFloat xBase,
                                         NSRect hoverBaseRect,
                                         NSRect linkRect,
                                         CGFloat padX,
                                         CGFloat padYTop,
                                         CGFloat padYBottom,
                                         CGFloat stripH,
                                         NSRect bounds) noexcept
{
    NSString *const t = titleSnippet.length > 24 ? [titleSnippet substringToIndex:24] : titleSnippet;
    const char *const ut = t.UTF8String;
    nc::panel::Log::Trace("[PathBarHover] layout seg={} title=\"{}\" xBase={:.3f} hoverBase=({:.3f},{:.3f},{:.3f},{:.3f}) "
                          "linkRect=({:.3f},{:.3f},{:.3f},{:.3f}) padX={:.3f} padYTop={:.3f} padYBottom={:.3f} "
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
                          padX,
                          padYTop,
                          padYBottom,
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
                                         NSRect bounds,
                                         CGFloat stripH,
                                         NSRect layoutStoredLinkRect) noexcept
{
    NSString *const t = titleSnippet.length > 24 ? [titleSnippet substringToIndex:24] : titleSnippet;
    const char *const ut = t.UTF8String;
    const NSRect inter = NSIntersectionRect(linkRect, bounds);
    nc::panel::Log::Trace("[PathBarHover] draw seg={} title=\"{}\" x={:.3f} yCont={:.3f} "
                          "used=({:.3f},{:.3f},{:.3f},{:.3f}) hoverBase=({:.3f},{:.3f},{:.3f},{:.3f}) "
                          "linkRect=({:.3f},{:.3f},{:.3f},{:.3f}) bounds=({:.3f},{:.3f},{:.3f},{:.3f}) "
                          "stripH={:.3f}",
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
                          bounds.origin.x,
                          bounds.origin.y,
                          bounds.size.width,
                          bounds.size.height,
                          stripH);
    const CGFloat dx = linkRect.origin.x - layoutStoredLinkRect.origin.x;
    const CGFloat dy = linkRect.origin.y - layoutStoredLinkRect.origin.y;
    const CGFloat dw = linkRect.size.width - layoutStoredLinkRect.size.width;
    const CGFloat dh = linkRect.size.height - layoutStoredLinkRect.size.height;
    nc::panel::Log::Trace("[PathBarHover] draw vs layout linkRect d.origin=({:.3f},{:.3f}) d.size=({:.3f},{:.3f}) "
                          "layoutStored=({:.3f},{:.3f},{:.3f},{:.3f}) link_inter_bounds=({:.3f},{:.3f},{:.3f},{:.3f})",
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

/// Snaps all four edges of a rect to the device pixel grid. Applied to the hover pill before filling
/// so the rounded rect has crisp edges on both @1x and @2x displays.
static NSRect NCBreadcrumbPixelAlignRect(NSRect r, CGFloat scale) noexcept
{
    const CGFloat x0 = std::round(r.origin.x * scale) / scale;
    const CGFloat y0 = std::round(r.origin.y * scale) / scale;
    const CGFloat x1 = std::round((r.origin.x + r.size.width) * scale) / scale;
    const CGFloat y1 = std::round((r.origin.y + r.size.height) * scale) / scale;
    return NSMakeRect(x0, y0, x1 - x0, y1 - y0);
}

/// Pre-laid-out TextKit state for one text item.
/// Created once in rebuildLayout and consumed in drawRect: by calling
/// drawGlyphsForGlyphRange:atPoint: with no new TextKit allocations in the hot path.
@interface NCBreadcrumbTextLayout : NSObject
@property(nonatomic, readonly) NSLayoutManager *lm;
@property(nonatomic, readonly) NSRange glyphRange;
@property(nonatomic, readonly) CGFloat yContainer;  ///< Container-origin Y for drawGlyphs:atPoint:
@property(nonatomic, readonly) CGFloat advance;     ///< Text advance width (= used.size.width)
@property(nonatomic, readonly) CGFloat usedHeight;  ///< Text used height (for tracing)
@property(nonatomic, readonly) NSRect hoverBase;    ///< Visual-glyph rect in view coords; for hover tracing
+ (nullable instancetype)layoutForText:(NSString *)text
                            attributes:(NSDictionary *)attrs
                          fallbackFont:(nullable NSFont *)fallbackFont
                                stripH:(CGFloat)stripH
                                 viewX:(CGFloat)viewX;
/// Returns a placeholder with no glyph data; drawing it is a no-op. Used when layoutForText: returns nil.
+ (instancetype)placeholderWithAdvance:(CGFloat)advance;
@end

/// Horizontal padding on each side of the › separator glyph: half the em size (rounded), floor 2pt, reads well at any font size.
static CGFloat NCBreadcrumbSeparatorSideInset(NSFont *font) noexcept
{
    const CGFloat pointSize = font != nil ? font.pointSize : 13.;
    return std::max<CGFloat>(2., std::round(pointSize * 0.5));
}

// Returns the vertical nudge (in points) to push the › glyph up for optical alignment with text.
// The › sits visually at x-height level while text glyphs reach cap height, so the glyph reads
// as low. The nudge is calculated as: coefficient * (capHeight - xHeight) — the gap between caps and lowercase —
// snapped to the physical pixel grid with a minimum of 1 physical pixel.
static CGFloat NCBreadcrumbSeparatorVerticalNudge(NSFont *font, CGFloat backingScale, CGFloat coefficient) noexcept
{
    const CGFloat capToX = font != nil ? std::max(0., font.capHeight - font.xHeight) : 2.3;
    const CGFloat raw = capToX * coefficient;
    return -(std::max(std::round(raw * backingScale), 1.) / backingScale);
}

/// When `layoutForText:...:stripH:0` returns nil (TextKit `usedRect` width &lt; 0.5pt), approximate width for layout math.
static CGFloat NCBreadcrumbTextFallbackAdvance(NSString *text, NSDictionary *attrs)
{
    if( text.length == 0 || attrs == nil )
        return 0.;
    const NSAttributedString *const as = [[NSAttributedString alloc] initWithString:text attributes:attrs];
    const NSRect b =
        [as boundingRectWithSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin];
    const CGFloat w = NSWidth(b);
    return std::max(0.5, w);
}

static CGFloat NCBreadcrumbSeparatorAdvance(NSDictionary *separatorAttributes, NSFont *font)
{
    NCBreadcrumbTextLayout *const lay = [NCBreadcrumbTextLayout layoutForText:kSep attributes:separatorAttributes
                                                                 fallbackFont:font stripH:0 viewX:0];
    const CGFloat glyphWidth = lay ? lay.advance : NCBreadcrumbTextFallbackAdvance(kSep, separatorAttributes);
    return glyphWidth + 2. * NCBreadcrumbSeparatorSideInset(font);
}

/// Center text container by the actual visual glyph box, no fixed optical offsets.
static CGFloat NCBreadcrumbCenterContainerYForVisualRect(CGFloat stripH, NSRect visualRect) noexcept
{
    if( visualRect.size.height <= 0. )
        return 0.;
    return (stripH - visualRect.size.height) * 0.5 - visualRect.origin.y;
}

@implementation NCBreadcrumbTextLayout {
    NSTextStorage *_ts;  ///< Keeps ts alive; NSLayoutManager holds only a weak back-reference to its text storage.
    NSLayoutManager *_lm;
    NSRange _glyphRange;
    CGFloat _yContainer;
    CGFloat _advance;
    CGFloat _usedHeight;
    NSRect _hoverBase;
}
@synthesize lm = _lm;
@synthesize glyphRange = _glyphRange;
@synthesize yContainer = _yContainer;
@synthesize advance = _advance;
@synthesize usedHeight = _usedHeight;
@synthesize hoverBase = _hoverBase;
+ (instancetype)placeholderWithAdvance:(CGFloat)advance
{
    NCBreadcrumbTextLayout *const item = [[NCBreadcrumbTextLayout alloc] init];
    item->_advance = advance;
    return item;
}
+ (nullable instancetype)layoutForText:(NSString *)text
                            attributes:(NSDictionary *)attrs
                          fallbackFont:(nullable NSFont *)fallbackFont
                                stripH:(CGFloat)stripH
                                 viewX:(CGFloat)viewX
{
    if( text.length == 0 || attrs == nil )
        return nil;
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
    if( used.size.width < 0.5 )
        return nil;
    const NSRange glyphRange = [lm glyphRangeForTextContainer:tc];

    NSFont *const font = nc::objc_cast<NSFont>([effectiveAttrs objectForKey:NSFontAttributeName]) ?: fallbackFont;

    CGFloat yContainer;
    NSRect hoverBase;
    if( stripH > 0. && glyphRange.length > 0 && font != nil ) {
        // Use font metrics to position the container and compute the hover-pill bounds.
        // NSLayoutManager's glyph bounding rect can include full typographic ascent/descent
        // even for short glyphs (e.g. all-x-height text), leaving unwanted space inside the
        // pill above the ink. Centering on capHeight gives a tight, consistent result
        // regardless of which specific glyphs are present in the label.
        const CGFloat capH = font.capHeight > 0. ? font.capHeight : font.ascender;
        // Baseline Y in the text container (Y increases downward from container top).
        const CGFloat baselineY = [lm locationForGlyphAtIndex:glyphRange.location].y;
        // Place the container so the cap-height range is centered in the strip.
        // Cap-height top in view = (stripH - capH) / 2  =>  yContainer = (stripH+capH)/2 - baselineY
        yContainer = (stripH + capH) * 0.5 - baselineY;
        hoverBase = NSMakeRect(viewX, (stripH - capH) * 0.5, used.size.width, capH);
    }
    else {
        // Fallback: used for width-only measurements (stripH == 0) or when font is unavailable.
        const NSRect gb = glyphRange.length ? [lm boundingRectForGlyphRange:glyphRange inTextContainer:tc] : NSZeroRect;
        const NSRect visualRect = (gb.size.width >= 0.5 && gb.size.height >= 0.5) ? gb : used;
        yContainer = NCBreadcrumbCenterContainerYForVisualRect(stripH, visualRect);
        hoverBase = NSMakeRect(viewX + visualRect.origin.x,
                               yContainer + visualRect.origin.y,
                               visualRect.size.width,
                               visualRect.size.height);
    }

    NCBreadcrumbTextLayout *const item = [[NCBreadcrumbTextLayout alloc] init];
    item->_ts = ts;
    item->_lm = lm;
    item->_glyphRange = glyphRange;
    item->_yContainer = yContainer;
    item->_advance = used.size.width;
    item->_usedHeight = used.size.height;
    item->_hoverBase = hoverBase;
    return item;
}
@end

@implementation NCPanelBreadcrumbsView {
    std::vector<nc::panel::PanelHeaderBreadcrumb> m_Breadcrumbs;
    /// Padded text line rects in view coords (link hit / hover), aligned with `m_TitleSegmentIndices`.
    NSMutableArray<NSValue *> *m_SegmentLinkRects;
    NSMutableArray<NSNumber *> *m_TitleSegmentIndices;
    NSInteger m_LayoutStartIndex;
    CGFloat m_LeadingEllipsisWidth;
    CGFloat m_ContentOriginX;
    /// Drawing cache: populated by rebuildLayout, consumed by drawRect: without new TextKit allocations.
    NCBreadcrumbTextLayout *m_DrawCacheEll;               ///< Leading "… " layout; nil when path fits without truncation.
    NCBreadcrumbTextLayout *m_DrawCacheSep;               ///< Separator "›" layout; shared for all separator draws.
    CGFloat m_DrawCacheSepAdvance;                        ///< Separator advance = glyph width + 2×side-inset.
    CGFloat m_DrawCacheSepSideInset;                      ///< Side spacing around the separator glyph.
    NSMutableArray<NCBreadcrumbTextLayout *> *m_DrawCacheSegments; ///< Per visible segment, from m_LayoutStartIndex.
}

@synthesize crumbDelegate = _crumbDelegate;
@synthesize hoveredSegmentIndex = _hoveredSegmentIndex;
@synthesize crumbFont = _crumbFont;
@synthesize textColor = _textColor;
@synthesize linkColor = _linkColor;
@synthesize separatorColor = _separatorColor;
@synthesize hoverFillColor = _hoverFillColor;
@synthesize hoverPadX = _hoverPadX;
@synthesize hoverPadY = _hoverPadY;
@synthesize hoverCornerRadius = _hoverCornerRadius;
@synthesize separatorVerticalNudgeCoefficient = _separatorVerticalNudgeCoefficient;
@synthesize menuForEventBlock = _menuForEventBlock;

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_SegmentLinkRects = [NSMutableArray array];
        m_TitleSegmentIndices = [NSMutableArray array];
        m_DrawCacheSegments = [NSMutableArray array];
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

- (void)setBreadcrumbs:(const std::vector<nc::panel::PanelHeaderBreadcrumb> &)breadcrumbs
{
    m_Breadcrumbs = breadcrumbs;
    [self rebuildLayout];
    [self setNeedsDisplay:YES];
}

- (NSDictionary *)titleAttributesForSegment:(const nc::panel::PanelHeaderBreadcrumb &)segment
{
    NSFont *const font = self.crumbFont ?: [NSFont systemFontOfSize:13];
    if( segment.navigate_to_vfs_path.has_value() && !segment.is_current_directory )
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

- (CGFloat)breadcrumbTrailWidthFromIndex:(NSInteger)start
                             breadcrumbs:(const std::vector<nc::panel::PanelHeaderBreadcrumb> &)breadcrumbs
                    includeSidePadding:(CGFloat)sidePaddingTotal
                    includeLeadingEllipsis:(BOOL)includeEllipsis
{
    NSFont *const font = self.crumbFont ?: [NSFont systemFontOfSize:13.];
    NSDictionary *const sepAttr = [self separatorAttributes];
    const CGFloat sepAdvance = NCBreadcrumbSeparatorAdvance(sepAttr, font);

    CGFloat w = sidePaddingTotal;
    if( includeEllipsis ) {
        NSDictionary *const ellAttrs = @{NSFontAttributeName: font};
        NCBreadcrumbTextLayout *const ell =
            [NCBreadcrumbTextLayout layoutForText:@"… " attributes:ellAttrs fallbackFont:font stripH:0 viewX:0];
        w += ell ? ell.advance : NCBreadcrumbTextFallbackAdvance(@"… ", ellAttrs);
    }
    for( NSInteger i = start; i < static_cast<NSInteger>(breadcrumbs.size()); ++i ) {
        const auto &segment = breadcrumbs[static_cast<size_t>(i)];
        NSString *const title = NCBreadcrumbLabel(segment);
        if( title.length == 0 )
            continue;
        if( i > start )
            w += sepAdvance;
        NSDictionary *const a = [self titleAttributesForSegment:segment];
        NCBreadcrumbTextLayout *const titleLay =
            [NCBreadcrumbTextLayout layoutForText:title attributes:a fallbackFont:font stripH:0 viewX:0];
        w += titleLay ? titleLay.advance : NCBreadcrumbTextFallbackAdvance(title, a);
    }
    return w;
}

- (CGFloat)measureTotalWidthFromStartIndex:(NSInteger)start includeLeadingEllipsis:(BOOL)ell
    breadcrumbs:(const std::vector<nc::panel::PanelHeaderBreadcrumb> &)breadcrumbs
    pad:(CGFloat)pad
{
    return [self breadcrumbTrailWidthFromIndex:start
                                   breadcrumbs:breadcrumbs
                          includeSidePadding:2. * pad
                          includeLeadingEllipsis:ell];
}

/// Width of ellipsis + visible titles and separators only (no side padding), for centering.
- (CGFloat)visibleTrailWidthFromStartIndex:(NSInteger)start
                               breadcrumbs:(const std::vector<nc::panel::PanelHeaderBreadcrumb> &)breadcrumbs
{
    return [self breadcrumbTrailWidthFromIndex:start
                                   breadcrumbs:breadcrumbs
                          includeSidePadding:0.
                          includeLeadingEllipsis:(start > 0)];
}

- (void)rebuildLayout
{
    [m_SegmentLinkRects removeAllObjects];
    [m_TitleSegmentIndices removeAllObjects];
    [m_DrawCacheSegments removeAllObjects];
    m_DrawCacheEll = nil;
    m_DrawCacheSep = nil;
    m_DrawCacheSepAdvance = 0.;
    m_DrawCacheSepSideInset = 0.;
    m_LayoutStartIndex = 0;
    m_LeadingEllipsisWidth = 0;
    m_ContentOriginX = 0.;

    const auto &breadcrumbs = m_Breadcrumbs;
    if( breadcrumbs.empty() || self.bounds.size.width < 8 )
        return;

    // Horizontal inset from view edges to breadcrumb content (not font-derived; pairs with truncation/centering math).
    const CGFloat pad = 6.;
    const CGFloat maxW = std::max(0., NSWidth(self.bounds) - 2 * pad);
    NSFont *const font = self.crumbFont ?: [NSFont systemFontOfSize:13.];

    NSInteger start = 0;
    while( start < static_cast<NSInteger>(breadcrumbs.size()) ) {
        const CGFloat tw = [self measureTotalWidthFromStartIndex:start
                                        includeLeadingEllipsis:(start > 0)
                                                     breadcrumbs:breadcrumbs
                                                             pad:pad];
        if( tw <= maxW )
            break;
        ++start;
    }
    m_LayoutStartIndex = start;

    const CGFloat trailW = [self visibleTrailWidthFromStartIndex:start breadcrumbs:breadcrumbs];
    const CGFloat boundsW = NSWidth(self.bounds);
    if( start > 0 ) {
        // Truncated: keep trail aligned to the leading padding (Finder-style).
        m_ContentOriginX = NCBreadcrumbAlignToPixelGrid(pad, NCBreadcrumbViewBackingScale(self));
    }
    else {
        // Full path fits: center the trail horizontally, snapped to the pixel grid.
        m_ContentOriginX =
            NCBreadcrumbAlignToPixelGrid(std::max(0., (boundsW - trailW) * 0.5), NCBreadcrumbViewBackingScale(self));
    }

    NSDictionary *const sepAttr = [self separatorAttributes];
    const CGFloat stripH = NSHeight(self.bounds);

    // Build draw cache for separator (shared for all separator draws; x is provided at draw time).
    m_DrawCacheSep = [NCBreadcrumbTextLayout layoutForText:kSep
                                               attributes:sepAttr
                                             fallbackFont:font
                                                   stripH:stripH
                                                    viewX:0.];
    m_DrawCacheSepSideInset = NCBreadcrumbSeparatorSideInset(font);
    m_DrawCacheSepAdvance = (m_DrawCacheSep ? m_DrawCacheSep.advance : 0.) + 2. * m_DrawCacheSepSideInset;

    CGFloat x = m_ContentOriginX;

    // Build draw cache for the leading ellipsis if the path is truncated.
    if( start > 0 ) {
        NSDictionary *const ellAttr = @{NSFontAttributeName: font,
                                        NSForegroundColorAttributeName: self.textColor ?: NSColor.textColor};
        m_DrawCacheEll = [NCBreadcrumbTextLayout layoutForText:@"… "
                                                    attributes:ellAttr
                                                  fallbackFont:font
                                                        stripH:stripH
                                                         viewX:x];
        m_LeadingEllipsisWidth = m_DrawCacheEll ? m_DrawCacheEll.advance : 0.;
        x += m_LeadingEllipsisWidth;
    }

    for( NSInteger i = start; i < static_cast<NSInteger>(breadcrumbs.size()); ++i ) {
        const auto &segment = breadcrumbs[static_cast<size_t>(i)];
        NSString *const title = NCBreadcrumbLabel(segment);
        if( title.length == 0 )
            continue;
        if( i > start )
            x += m_DrawCacheSepAdvance;
        NSDictionary *const a = [self titleAttributesForSegment:segment];
        // Single TextKit pass yields both the draw-cache item and the hover-base rect.
        NCBreadcrumbTextLayout *segItem = [NCBreadcrumbTextLayout layoutForText:title
                                                                     attributes:a
                                                                   fallbackFont:font
                                                                         stripH:stripH
                                                                          viewX:x];
        if( segItem == nil ) {
            // layoutForText: returns nil only when used width < 0.5pt (degenerate case). A second TextKit pass
            // with the same parameters also returns nil; use attributed bounding width for layout/draw x sync.
            const CGFloat measuredAdvance = NCBreadcrumbTextFallbackAdvance(title, a);
            segItem = [NCBreadcrumbTextLayout placeholderWithAdvance:measuredAdvance];
        }
        [m_DrawCacheSegments addObject:segItem];
        const NSRect hoverBase = segItem.hoverBase;
        const CGFloat padX = self.hoverPadX;
        const CGFloat padY = self.hoverPadY;
        const NSRect linkRect = NCBreadcrumbPaddedLinkRect(hoverBase, padX, padY, padY);
        if( nc::panel::Log::Level() <= spdlog::level::trace )
            NCBreadcrumbTraceHoverLayout(title, i, x, hoverBase, linkRect, padX, padY, padY, stripH, self.bounds);
        [m_SegmentLinkRects addObject:[NSValue valueWithRect:linkRect]];
        [m_TitleSegmentIndices addObject:@(i)];
        x += segItem.advance;
    }
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    self.needsLayout = YES;
}

- (void)layout
{
    [super layout];
    [self rebuildLayout];
}

- (NSInteger)segmentIndexAtPoint:(NSPoint)p
{
    NSFont *const font = self.crumbFont ?: [NSFont systemFontOfSize:13.];
    const CGFloat hSlop = NCBreadcrumbHitTestHorizontalSlop(font);
    const CGFloat vSlop = NCBreadcrumbHitTestVerticalSlop(font);
    for( NSUInteger i = 0; i < m_SegmentLinkRects.count; ++i ) {
        const NSRect r = NSInsetRect([m_SegmentLinkRects[i] rectValue], -hSlop, -vSlop);
        if( NSPointInRect(p, r) )
            return [m_TitleSegmentIndices[i] integerValue];
    }
    return -1;
}

- (nullable NSString *)posixPathAtViewPoint:(NSPoint)p fallbackPOSIXPath:(nullable NSString *)fallback plainPath:(nullable NSString *)plain
{
    if( m_Breadcrumbs.empty() )
        return plain.length ? plain : nil;
    const NSInteger idx = [self segmentIndexAtPoint:p];
    if( idx < 0 )
        return fallback.length ? fallback : (plain.length ? plain : nil);
    const auto &segment = m_Breadcrumbs[static_cast<size_t>(idx)];
    const auto resolved = nc::panel::ResolvePanelBreadcrumbSegmentPOSIXForMenu(
        segment.is_current_directory,
        segment.navigate_to_vfs_path,
        NCBreadcrumbOptionalUTF8(fallback),
        NCBreadcrumbOptionalUTF8(plain));
    if( !resolved.has_value() )
        return nil;
    return [NSString stringWithUTF8String:resolved->c_str()];
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    if( m_Breadcrumbs.empty() || NSWidth(self.bounds) < 8 )
        return;

    const NSInteger start = m_LayoutStartIndex;
    const CGFloat stripH = NSHeight(self.bounds);
    const CGFloat boundsW = NSWidth(self.bounds);

    CGFloat x = m_ContentOriginX;

    // Draw leading ellipsis from cache (no TextKit allocation).
    if( start > 0 && m_DrawCacheEll != nil ) {
        NSGraphicsContext *const gctx = NSGraphicsContext.currentContext;
        [gctx saveGraphicsState];
        [[NSBezierPath bezierPathWithRect:NSMakeRect(0., 0., boundsW, stripH)] addClip];
        [m_DrawCacheEll.lm drawGlyphsForGlyphRange:m_DrawCacheEll.glyphRange
                                           atPoint:NSMakePoint(x, m_DrawCacheEll.yContainer)];
        [gctx restoreGraphicsState];
        x += m_DrawCacheEll.advance;
    }

    NSUInteger segCacheIdx = 0;
    // Separator nudge is a display-scale correction; compute once per repaint (pure arithmetic, no allocation).
    const CGFloat sepNudge = NCBreadcrumbSeparatorVerticalNudge(self.crumbFont, NCBreadcrumbViewBackingScale(self), self.separatorVerticalNudgeCoefficient);
    for( NSInteger i = start; i < static_cast<NSInteger>(m_Breadcrumbs.size()); ++i ) {
        const auto &segment = m_Breadcrumbs[static_cast<size_t>(i)];
        NSString *const title = NCBreadcrumbLabel(segment);
        if( title.length == 0 )
            continue;

        // Draw separator from cache (shared item; x is provided here, not baked into the cache).
        if( i > start && m_DrawCacheSep != nil ) {
            NSGraphicsContext *const gctx = NSGraphicsContext.currentContext;
            [gctx saveGraphicsState];
            [[NSBezierPath bezierPathWithRect:NSMakeRect(0., 0., boundsW, stripH)] addClip];
            [m_DrawCacheSep.lm drawGlyphsForGlyphRange:m_DrawCacheSep.glyphRange
                                               atPoint:NSMakePoint(x + m_DrawCacheSepSideInset,
                                                                   m_DrawCacheSep.yContainer + sepNudge)];
            [gctx restoreGraphicsState];
            x += m_DrawCacheSepAdvance;
        }

        if( segCacheIdx >= m_DrawCacheSegments.count ) {
            continue; // caches out of sync, skip drawing, do not advance index
        }
        NCBreadcrumbTextLayout *const segItem = m_DrawCacheSegments[segCacheIdx++];

        const bool isHovered = (self.hoveredSegmentIndex == i &&
                                self.hoverFillColor &&
                                self.hoverFillColor != NSColor.clearColor);
        NSRect hoverBase = NSZeroRect;
        NSRect hr = NSZeroRect;

        if( isHovered ) {
            const CGFloat padX = self.hoverPadX;
            const CGFloat padY = self.hoverPadY;
            const CGFloat cr = static_cast<CGFloat>(self.hoverCornerRadius);
            hoverBase = segItem.hoverBase;
            hr = NCBreadcrumbPixelAlignRect(NCBreadcrumbPaddedLinkRect(hoverBase, padX, padY, padY),
                                            NCBreadcrumbViewBackingScale(self));
            NSGraphicsContext *const gctx = NSGraphicsContext.currentContext;
            [gctx saveGraphicsState];
            [[NSBezierPath bezierPathWithRect:self.bounds] addClip];
            if( hr.size.width >= 1. && hr.size.height >= 0.5 ) {
                [self.hoverFillColor setFill];
                [[NSBezierPath bezierPathWithRoundedRect:hr xRadius:cr yRadius:cr] fill];
            }
            [gctx restoreGraphicsState];
        }

        // Draw segment title from cache (no TextKit allocation).
        {
            NSGraphicsContext *const gctx = NSGraphicsContext.currentContext;
            [gctx saveGraphicsState];
            [[NSBezierPath bezierPathWithRect:NSMakeRect(0., 0., boundsW, stripH)] addClip];
            [segItem.lm drawGlyphsForGlyphRange:segItem.glyphRange atPoint:NSMakePoint(x, segItem.yContainer)];
            [gctx restoreGraphicsState];
        }

        if( isHovered && nc::panel::Log::Level() <= spdlog::level::trace ) {
            // segCacheIdx was already incremented after fetching segItem, so [segCacheIdx-1] aligns with this segment.
            const NSRect layoutStoredLink = [m_SegmentLinkRects[segCacheIdx - 1] rectValue];
            const NSRect usedTitle = NSMakeRect(x, segItem.yContainer, segItem.advance, segItem.usedHeight);
            NCBreadcrumbTraceHoverDraw(i, title, x, segItem.yContainer, usedTitle, hoverBase, hr,
                                       self.bounds, stripH, layoutStoredLink);
        }

        x += segItem.advance;
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

    if( [self.crumbDelegate respondsToSelector:@selector(breadcrumbsViewWillHandleMouseDown:)] )
        [self.crumbDelegate breadcrumbsViewWillHandleMouseDown:self];

    if( event.clickCount >= 2 ) {
        if( [self.crumbDelegate respondsToSelector:@selector(breadcrumbsViewDidRequestFullPathEdit:)] )
            [self.crumbDelegate breadcrumbsViewDidRequestFullPathEdit:self];
        return;
    }
    const NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    const NSInteger idx = [self segmentIndexAtPoint:p];
    if( idx < 0 )
        return;
    const auto &segment = m_Breadcrumbs[static_cast<size_t>(idx)];
    if( segment.is_current_directory ) {
        if( [self.crumbDelegate respondsToSelector:@selector(breadcrumbsViewDidActivateCurrentSegment:)] )
            [self.crumbDelegate breadcrumbsViewDidActivateCurrentSegment:self];
    }
    else {
        NSString *const navigate_path = NCBreadcrumbNavigatePath(segment);
        if( navigate_path.length == 0 )
            return;
        if( [self.crumbDelegate respondsToSelector:@selector(breadcrumbsView:didActivatePOSIXPath:)] )
            [self.crumbDelegate breadcrumbsView:self didActivatePOSIXPath:navigate_path];
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

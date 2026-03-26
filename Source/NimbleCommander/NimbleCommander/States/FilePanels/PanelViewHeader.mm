// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelViewHeader.h"
#include <algorithm>
#include <cmath>
#include <Utility/Layout.h>
#include <Utility/ObjCpp.h>
#include <Utility/ColoredSeparatorLine.h>

using namespace nc::panel;

static NSString *const NCPanelPathBarCurrentCrumbAttributeName = @"NCPanelPathBarCurrentCrumb";

static CGFloat NCPanelPathBarOneDisplayPixelInPoints(NSView *view) noexcept
{
    CGFloat s = 0.;
    if( view.window != nil )
        s = view.window.backingScaleFactor;
    if( s <= 0.01 && view.window.screen != nil )
        s = view.window.screen.backingScaleFactor;
    if( s <= 0.01 )
        s = NSScreen.mainScreen.backingScaleFactor;
    if( s <= 0.01 )
        s = 2.;
    return 1. / s;
}

static CGFloat NCPanelPathBarTypographicLineHeight(NSFont *font) noexcept
{
    if( !font )
        return 0.;
    NSLayoutManager *const lm = [[NSLayoutManager alloc] init];
    return std::ceil([lm defaultLineHeightForFont:font]);
}

// Same padding top and bottom around the typographic line, except an extra 1 display pixel at the bottom
// of the strip (taller bar + content shifted up by that pixel vs symmetric centering).
static constexpr CGFloat NCPanelPathBarVerticalPaddingPoints = 4.0;

static CGFloat NCPanelPathBarAdaptiveRowHeight(NSFont *font, NSView *view) noexcept
{
    const CGFloat line = NCPanelPathBarTypographicLineHeight(font);
    const CGFloat bottom_extra = NCPanelPathBarOneDisplayPixelInPoints(view);
    const CGFloat h = line + 2.0 * NCPanelPathBarVerticalPaddingPoints + bottom_extra;
    return std::ceil(std::max<CGFloat>(h, 1.0));
}

// Flipped view (NSTextView): NSMinY is the top — padding is measured from the top edge.
static NSRect NCPanelPathBarTypographicLineRectInStripBounds(NSRect bounds, NSFont *font) noexcept
{
    const CGFloat lh = NCPanelPathBarTypographicLineHeight(font);
    if( lh <= 0.5 )
        return bounds;
    bounds.origin.y = std::floor(NSMinY(bounds) + NCPanelPathBarVerticalPaddingPoints);
    bounds.size.height = lh;
    return bounds;
}

// Non-flipped cell (NSTextFieldCell): NSRect.origin.y is the bottom of the rect; match strip layout
// (T top, T + bottomExtra below line) so edit mode matches breadcrumbs.
static NSRect NCPanelPathBarTypographicLineRectInStripCellBounds(NSRect bounds, NSFont *font, NSView *view) noexcept
{
    const CGFloat lh = NCPanelPathBarTypographicLineHeight(font);
    if( lh <= 0.5 )
        return bounds;
    const CGFloat T = NCPanelPathBarVerticalPaddingPoints;
    const CGFloat bottom_extra = NCPanelPathBarOneDisplayPixelInPoints(view);
    bounds.origin.y = std::floor(NSMinY(bounds) + T + bottom_extra);
    bounds.size.height = lh;
    return bounds;
}

static NSString *SortLetter(data::SortMode _mode) noexcept;
static void ChangeButtonAttrString(NSButton *_button, NSColor *_new_color, NSFont *_font);
static void ChangeAttributedTitle(NSButton *_button, NSString *_new_text);
static bool IsDark(NSColor *_color);
static NSURL *PanelHeaderMakeLinkURLFromVFSPath(const std::string &_path) noexcept;
static NSMutableAttributedString *PanelHeaderBuildInteractivePathAttributedString(const std::vector<PanelHeaderBreadcrumb> &_crumbs,
                                                                                NSFont *_font,
                                                                                NSColor *_text_color);
static NSMutableAttributedString *PanelHeaderBuildPlainPathAttributedString(NSString *_path, NSFont *_font, NSColor *_text_color);

@class NCPanelViewHeader;

@interface NCPanelViewHeader (PathBarEditingPrivate)
- (BOOL)panelPathBarIsInteractive;
- (void)beginInlinePathEditing;
- (nullable NSString *)posixPathForPathBarContextMenuAtPoint:(NSPoint)pInTextViewCoords;
- (NSMenu *)pathBarContextMenuForPOSIXPath:(NSString *)path;
- (void)handlePathBarContextMenuItem:(NSMenuItem *)item;
@end

@interface NCPanelPathDisplayTextView : NSTextView
@property(nonatomic, weak) NCPanelViewHeader *pathHeader;
@property(nonatomic, strong) NSColor *pathAccentColor;
- (void)clearHover;
- (NSRect)nc_hoverBackgroundRectForCharacterRange:(NSRange)range;
@end

@implementation NCPanelPathDisplayTextView {
    NSRange m_HoveredRange;
}

@synthesize pathHeader;
@synthesize pathAccentColor;

- (NSPoint)textContainerOrigin
{
    NSPoint o = [super textContainerOrigin];
    o.y = NSMinY(NCPanelPathBarTypographicLineRectInStripBounds(self.bounds, self.font));
    return o;
}

- (void)resetCursorRects
{
    if( self.bounds.size.width > 0 && self.bounds.size.height > 0 )
        [self addCursorRect:self.bounds cursor:[NSCursor arrowCursor]];
}

- (void)cursorUpdate:(NSEvent *)event
{
    (void)event;
    [[NSCursor arrowCursor] set];
}

- (void)updateTrackingAreas
{
    [super updateTrackingAreas];
    for( NSTrackingArea *ta in [self.trackingAreas copy] )
        if( ta.owner == self )
            [self removeTrackingArea:ta];
    if( self.bounds.size.width > 0 && self.bounds.size.height > 0 ) {
        auto *const ta = [[NSTrackingArea alloc]
            initWithRect:self.bounds
                 options:NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow
                   owner:self
                userInfo:nil];
        [self addTrackingArea:ta];
    }
}

- (void)mouseMoved:(NSEvent *)event
{
    if( !self.pathAccentColor || ![self.pathHeader panelPathBarIsInteractive] ) {
        [super mouseMoved:event];
        return;
    }
    const NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    if( ![self nc_pointIsInsideLaidOutPathGlyphs:p] ) {
        [self setHoveredRange:NSMakeRange(NSNotFound, 0)];
        return;
    }
    const NSUInteger idx = [self characterIndexForInsertionAtPoint:p];
    if( idx >= self.textStorage.length ) {
        [self setHoveredRange:NSMakeRange(NSNotFound, 0)];
        return;
    }
    NSRange range = {};
    id link = [self.textStorage attribute:NSLinkAttributeName atIndex:idx effectiveRange:&range];
    [self setHoveredRange:(link && NSLocationInRange(idx, range)) ? range : NSMakeRange(NSNotFound, 0)];
}

- (void)mouseExited:(NSEvent *)event
{
    [self setHoveredRange:NSMakeRange(NSNotFound, 0)];
    [super mouseExited:event];
}

- (void)setHoveredRange:(NSRange)range
{
    if( NSEqualRanges(m_HoveredRange, range) )
        return;
    const NSRange prev = m_HoveredRange;
    m_HoveredRange = range;
    // Rounded hover is drawn in drawRect: (NSBackgroundColorAttributeName is rectangular only).
    if( prev.location != NSNotFound )
        [self setNeedsDisplayInRect:[self nc_hoverBackgroundRectForCharacterRange:prev]];
    if( range.location != NSNotFound )
        [self setNeedsDisplayInRect:[self nc_hoverBackgroundRectForCharacterRange:range]];
}

- (NSRect)nc_hoverBackgroundRectForCharacterRange:(NSRange)range
{
    if( range.location == NSNotFound || range.length == 0 )
        return NSZeroRect;
    if( self.textStorage.length == 0 || range.location >= self.textStorage.length )
        return NSZeroRect;
    NSLayoutManager *const lm = self.layoutManager;
    NSTextContainer *const tc = self.textContainer;
    if( !lm || !tc )
        return NSZeroRect;

    NSRange actual = {};
    const NSRange glyph_range = [lm glyphRangeForCharacterRange:range actualCharacterRange:&actual];
    if( glyph_range.length == 0 )
        return NSZeroRect;

    NSRect r = [lm boundingRectForGlyphRange:glyph_range inTextContainer:tc];
    const NSPoint o = [self textContainerOrigin];
    r.origin.x += o.x;
    r.origin.y += o.y;

    static constexpr CGFloat kPadX = 2.0;
    static constexpr CGFloat kPadY = 0.5;
    r = NSInsetRect(r, -kPadX, 0.0);
    const NSRect line = NCPanelPathBarTypographicLineRectInStripBounds(self.bounds, self.font);
    r.origin.y = NSMinY(line) - kPadY;
    r.size.height = NSHeight(line) + 2.0 * kPadY;
    r = NSIntersectionRect(r, self.bounds);
    if( r.size.height < 2.0 )
        return NSZeroRect;

    r.origin.x = std::floor(r.origin.x) + 0.5;
    r.origin.y = std::floor(r.origin.y) + 0.5;
    r.size.width = std::ceil(r.size.width);
    r.size.height = std::ceil(r.size.height);
    return r;
}

- (void)drawRect:(NSRect)dirtyRect
{
    if( m_HoveredRange.location != NSNotFound && self.pathAccentColor ) {
        const NSRect r = [self nc_hoverBackgroundRectForCharacterRange:m_HoveredRange];
        if( !NSIsEmptyRect(NSIntersectionRect(dirtyRect, r)) ) {
            [self.pathAccentColor setFill];
            const CGFloat radius = std::min<CGFloat>(4.0, std::floor(r.size.height * 0.5));
            [[NSBezierPath bezierPathWithRoundedRect:r xRadius:radius yRadius:radius] fill];
        }
    }
    [super drawRect:dirtyRect];
}

- (void)clearHover
{
    [self setHoveredRange:NSMakeRange(NSNotFound, 0)];
}

- (void)layout
{
    [super layout];
    if( self.window != nil )
        [self.window invalidateCursorRectsForView:self];
}

- (void)copy:(id)sender
{
    (void)sender;
    NSString *const s = self.string;
    if( s.length == 0 )
        return;
    NSPasteboard *const pb = NSPasteboard.generalPasteboard;
    [pb clearContents];
    [pb setString:s forType:NSPasteboardTypeString];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    if( item.action == @selector(copy:) )
        return self.string.length > 0;
    return [super validateMenuItem:item];
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
    // With selectable=NO the text view never builds its own context menu and never calls the
    // textView:menu:forEvent:atIndex: delegate. We must intercept menuForEvent: here directly.
    NCPanelViewHeader *const header = self.pathHeader;
    if( !header || !header.pathBarContextMenuAction )
        return [super menuForEvent:event];
    const NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    NSString *const path = [header posixPathForPathBarContextMenuAtPoint:p];
    if( path.length == 0 )
        return [super menuForEvent:event];
    return [header pathBarContextMenuForPOSIXPath:path];
}

- (BOOL)nc_pointIsInsideLaidOutPathGlyphs:(NSPoint)p_in_view_coords
{
    if( self.textStorage.length == 0 )
        return NO;
    NSLayoutManager *const lm = self.layoutManager;
    NSTextContainer *const tc = self.textContainer;
    NSRect used = [lm usedRectForTextContainer:tc];
    if( used.size.width <= 0 || used.size.height <= 0 )
        return NO;
    const NSPoint o = [self textContainerOrigin];
    used.origin.x += o.x;
    used.origin.y += o.y;
    return NSPointInRect(p_in_view_coords, used);
}

- (void)mouseDown:(NSEvent *)event
{
    if( !self.pathHeader ) {
        [super mouseDown:event];
        return;
    }
    if( ![self.pathHeader panelPathBarIsInteractive] ) {
        [super mouseDown:event];
        return;
    }

    const NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    const bool over_glyphs = [self nc_pointIsInsideLaidOutPathGlyphs:p];

    if( event.clickCount >= 2 && !over_glyphs ) {
        [self.pathHeader beginInlinePathEditing];
        return;
    }

    if( !over_glyphs )
        return;

    const NSUInteger len = self.textStorage.length;
    const NSUInteger idx = [self characterIndexForInsertionAtPoint:p];
    if( len == 0 || idx >= len )
        return;

    NSRange attr_range = {};
    id is_current = [self.textStorage attribute:NCPanelPathBarCurrentCrumbAttributeName atIndex:idx effectiveRange:&attr_range];
    if( is_current && NSLocationInRange(idx, attr_range) ) {
        [self.pathHeader beginInlinePathEditing];
        return;
    }

    NSRange link_range = {};
    id link = [self.textStorage attribute:NSLinkAttributeName atIndex:idx effectiveRange:&link_range];
    if( link && NSLocationInRange(idx, link_range) ) {
        id<NSTextViewDelegate> dg = self.delegate;
        if( [dg respondsToSelector:@selector(textView:clickedOnLink:atIndex:)] ) {
            [dg textView:self clickedOnLink:link atIndex:link_range.location];
        }
    }
}
@end

@interface NCPanelPathChromeTextFieldCell : NSTextFieldCell
@end

@implementation NCPanelPathChromeTextFieldCell

- (NSRect)drawingRectForBounds:(NSRect)rect
{
    return NCPanelPathBarTypographicLineRectInStripCellBounds(rect, self.font, self.controlView);
}

- (NSRect)editingRectForBounds:(NSRect)rect
{
    return NCPanelPathBarTypographicLineRectInStripCellBounds(rect, self.font, self.controlView);
}

- (void)selectWithFrame:(NSRect)aRect
                 inView:(NSView *)controlView
                 editor:(NSText *)textObj
               delegate:(id)anObject
                  start:(NSInteger)selStart
                 length:(NSInteger)selLength
{
    const NSRect r = NCPanelPathBarTypographicLineRectInStripCellBounds(aRect, self.font, controlView);
    [super selectWithFrame:r inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void)editWithFrame:(NSRect)aRect
               inView:(NSView *)controlView
               editor:(NSText *)textObj
             delegate:(id)anObject
                event:(NSEvent *)event
{
    const NSRect r = NCPanelPathBarTypographicLineRectInStripCellBounds(aRect, self.font, controlView);
    [super editWithFrame:r inView:controlView editor:textObj delegate:anObject event:event];
}

@end

@interface NCPanelPathChromeTextField : NSTextField
@end

@implementation NCPanelPathChromeTextField

+ (Class)cellClass
{
    return NCPanelPathChromeTextFieldCell.class;
}

- (void)resetCursorRects
{
    if( self.bounds.size.width > 0 && self.bounds.size.height > 0 )
        [self addCursorRect:self.bounds cursor:[NSCursor arrowCursor]];
}

- (void)cursorUpdate:(NSEvent *)event
{
    (void)event;
    [[NSCursor arrowCursor] set];
}

@end

@interface NCPanelViewHeader ()
@property(nonatomic) IBOutlet NSMenu *sortMenuPopup;
- (void)updatePathBarHeightConstraints;
@end

@implementation NCPanelViewHeader {
    NSView *m_PathArea;
    NCPanelPathDisplayTextView *m_PathTextView;
    NSTextField *m_PathEditField;
    NSTextField *m_SearchTextField;
    NSTextField *m_SearchMatchesField;
    NSButton *m_SearchMagGlassButton;
    NSButton *m_SearchClearButton;

    ColoredSeparatorLine *m_SeparatorLine;
    NSColor *m_Background;
    NSString *m_SearchPrompt;
    NSButton *m_SortButton;
    NSProgressIndicator *m_BusyIndicator;
    data::SortMode m_SortMode;
    std::function<void(data::SortMode)> m_SortModeChangeCallback;
    std::function<void(NSString *)> m_SearchRequestChangeCallback;
    std::unique_ptr<nc::panel::HeaderTheme> m_Theme;
    bool m_Active;

    bool m_PathBarInteractive;
    std::vector<PanelHeaderBreadcrumb> m_LastBreadcrumbs;
    NSString *m_LastPlainPath;
    NSString *m_LastFullPathForEditing;
    std::function<void(const std::string &)> m_PathNavigateCallback;
    std::function<void(NSString *)> m_PathCommitCallback;
    id m_PathEditOutsideClickMonitor;
    uint64_t m_PathEditCommitSeq;
    NSLayoutConstraint *m_StripHeightConstraint;
    NSLayoutConstraint *m_PathAreaHeightConstraint;
}

@synthesize sortMode = m_SortMode;
@synthesize sortModeChangeCallback = m_SortModeChangeCallback;
@synthesize defaultResponder;
@synthesize sortMenuPopup;
@synthesize pathNavigateToVFSPathCallback = m_PathNavigateCallback;
@synthesize pathManualEntryCommitCallback = m_PathCommitCallback;
@synthesize pathBarContextMenuAction;

- (void)dealloc
{
    [self removePathEditOutsideClickMonitorIfNeeded];
}

- (id)initWithFrame:(NSRect)frameRect theme:(std::unique_ptr<nc::panel::HeaderTheme>)_theme
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_Theme = std::move(_theme);
        m_SearchPrompt = nil;
        m_Active = false;
        m_PathBarInteractive = false;
        m_PathEditCommitSeq = 0;
        m_StripHeightConstraint = nil;
        m_PathAreaHeightConstraint = nil;

        m_PathArea = [[NSView alloc] initWithFrame:NSRect()];
        m_PathArea.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_PathArea];

        m_PathTextView = [[NCPanelPathDisplayTextView alloc] initWithFrame:NSRect()];
        m_PathTextView.pathHeader = self;
        m_PathTextView.translatesAutoresizingMaskIntoConstraints = false;
        m_PathTextView.editable = false;
        m_PathTextView.selectable = false;
        m_PathTextView.richText = true;
        m_PathTextView.importsGraphics = false;
        m_PathTextView.drawsBackground = false;
        m_PathTextView.focusRingType = NSFocusRingTypeNone;
        m_PathTextView.horizontallyResizable = false;
        m_PathTextView.verticallyResizable = false;
        m_PathTextView.textContainer.lineFragmentPadding = 0;
        m_PathTextView.textContainer.widthTracksTextView = true;
        m_PathTextView.textContainer.heightTracksTextView = true;
        m_PathTextView.textContainerInset = NSMakeSize(0, 0);
        m_PathTextView.alignment = NSTextAlignmentCenter;
        m_PathTextView.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
        m_PathTextView.minSize = NSMakeSize(0, 0);
        m_PathTextView.delegate = self;
        [m_PathArea addSubview:m_PathTextView];

        m_PathEditField = [[NCPanelPathChromeTextField alloc] initWithFrame:NSRect()];
        m_PathEditField.translatesAutoresizingMaskIntoConstraints = false;
        m_PathEditField.stringValue = @"";
        m_PathEditField.bordered = false;
        m_PathEditField.bezeled = false;
        m_PathEditField.editable = true;
        m_PathEditField.drawsBackground = false;
        m_PathEditField.lineBreakMode = NSLineBreakByTruncatingHead;
        m_PathEditField.maximumNumberOfLines = 1;
        m_PathEditField.alignment = NSTextAlignmentCenter;
        m_PathEditField.focusRingType = NSFocusRingTypeNone;
        m_PathEditField.hidden = true;
        m_PathEditField.delegate = self;
        [m_PathArea addSubview:m_PathEditField];

        [NSLayoutConstraint activateConstraints:@[
            [m_PathTextView.leadingAnchor constraintEqualToAnchor:m_PathArea.leadingAnchor],
            [m_PathTextView.trailingAnchor constraintEqualToAnchor:m_PathArea.trailingAnchor],
            [m_PathTextView.topAnchor constraintEqualToAnchor:m_PathArea.topAnchor],
            [m_PathTextView.bottomAnchor constraintEqualToAnchor:m_PathArea.bottomAnchor],
            [m_PathEditField.leadingAnchor constraintEqualToAnchor:m_PathArea.leadingAnchor],
            [m_PathEditField.trailingAnchor constraintEqualToAnchor:m_PathArea.trailingAnchor],
            [m_PathEditField.topAnchor constraintEqualToAnchor:m_PathArea.topAnchor],
            [m_PathEditField.bottomAnchor constraintEqualToAnchor:m_PathArea.bottomAnchor],
        ]];

        m_SearchTextField = [[NSTextField alloc] initWithFrame:NSRect()];
        m_SearchTextField.stringValue = @"";
        m_SearchTextField.translatesAutoresizingMaskIntoConstraints = false;
        m_SearchTextField.target = self;
        m_SearchTextField.action = @selector(onSearchFieldAction:);
        m_SearchTextField.bordered = false;
        m_SearchTextField.bezeled = false;
        m_SearchTextField.editable = true;
        m_SearchTextField.drawsBackground = false;
        m_SearchTextField.lineBreakMode = NSLineBreakByTruncatingHead;
        m_SearchTextField.maximumNumberOfLines = 1;
        m_SearchTextField.alignment = NSTextAlignmentCenter;
        m_SearchTextField.focusRingType = NSFocusRingTypeNone;
        m_SearchTextField.delegate = self;
        [self addSubview:m_SearchTextField];

        m_SearchMatchesField = [[NSTextField alloc] initWithFrame:NSRect()];
        m_SearchMatchesField.stringValue = @"";
        m_SearchMatchesField.translatesAutoresizingMaskIntoConstraints = false;
        m_SearchMatchesField.bordered = false;
        m_SearchMatchesField.editable = false;
        m_SearchMatchesField.drawsBackground = false;
        m_SearchMatchesField.lineBreakMode = NSLineBreakByTruncatingHead;
        m_SearchMatchesField.maximumNumberOfLines = 1;
        m_SearchMatchesField.alignment = NSTextAlignmentRight;
        [self addSubview:m_SearchMatchesField];

        m_SearchClearButton = [[NSButton alloc] initWithFrame:NSRect()];
        m_SearchClearButton.translatesAutoresizingMaskIntoConstraints = false;
        m_SearchClearButton.image = [NSImage imageWithSystemSymbolName:@"xmark.circle.fill"
                                              accessibilityDescription:nil];
        m_SearchClearButton.imageScaling = NSImageScaleProportionallyDown;
        m_SearchClearButton.refusesFirstResponder = true;
        m_SearchClearButton.bordered = false;
        m_SearchClearButton.target = self;
        m_SearchClearButton.action = @selector(onSearchFieldDiscardButton:);
        [self addSubview:m_SearchClearButton];

        m_SearchMagGlassButton = [[NSButton alloc] initWithFrame:NSRect()];
        m_SearchMagGlassButton.translatesAutoresizingMaskIntoConstraints = false;
        m_SearchMagGlassButton.image = [NSImage imageWithSystemSymbolName:@"magnifyingglass"
                                                 accessibilityDescription:nil];
        m_SearchMagGlassButton.imageScaling = NSImageScaleProportionallyDown;
        m_SearchMagGlassButton.refusesFirstResponder = true;
        m_SearchMagGlassButton.bordered = false;
        m_SearchMagGlassButton.enabled = false;
        [self addSubview:m_SearchMagGlassButton];

        m_SeparatorLine = [[ColoredSeparatorLine alloc] initWithFrame:NSRect()];
        m_SeparatorLine.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_SeparatorLine];

        m_SortButton = [[NSButton alloc] initWithFrame:NSRect()];
        m_SortButton.translatesAutoresizingMaskIntoConstraints = false;
        m_SortButton.title = @"N";
        m_SortButton.bordered = false;
        m_SortButton.buttonType = NSButtonTypeMomentaryChange;
        [m_SortButton sendActionOn:NSEventMaskLeftMouseDown];
        m_SortButton.action = @selector(onSortButtonAction:);
        m_SortButton.target = self;
        m_SortButton.enabled = true;
        [self addSubview:m_SortButton];

        m_BusyIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
        m_BusyIndicator.translatesAutoresizingMaskIntoConstraints = false;
        m_BusyIndicator.indeterminate = true;
        m_BusyIndicator.style = NSProgressIndicatorStyleSpinning;
        m_BusyIndicator.controlSize = NSControlSizeSmall;
        m_BusyIndicator.displayedWhenStopped = false;
        if( IsDark(m_Theme->ActiveBackgroundColor()) )
            m_BusyIndicator.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
        [self addSubview:m_BusyIndicator positioned:NSWindowAbove relativeTo:m_PathArea];

        [self setupAppearance];
        [self setupLayout];

        // Own strip height here so it does not depend on PanelView adding an external height constraint.
        m_StripHeightConstraint = [self.heightAnchor constraintEqualToConstant:1.0];
        m_StripHeightConstraint.priority = NSLayoutPriorityRequired;
        m_StripHeightConstraint.identifier = @"NCPanelViewHeader.StripHeight";
        m_StripHeightConstraint.active = YES;
        [self updatePathBarHeightConstraints];

        __weak NCPanelViewHeader *weak_self = self;
        m_Theme->ObserveChanges([weak_self] {
            if( auto strong_self = weak_self )
                [strong_self setupAppearance];
        });
    }
    return self;
}

- (BOOL)panelPathBarIsInteractive
{
    return m_PathBarInteractive;
}

- (void)removePathEditOutsideClickMonitorIfNeeded
{
    if( m_PathEditOutsideClickMonitor != nil ) {
        [NSEvent removeMonitor:m_PathEditOutsideClickMonitor];
        m_PathEditOutsideClickMonitor = nil;
    }
}

- (void)handleOutsideMouseDownWhilePathEditing:(NSEvent *)event
{
    if( m_PathEditField.hidden )
        return;
    NSWindow *const event_window = event.window;
    if( !event_window )
        return;
    if( event_window != self.window ) {
        [self cancelInlinePathEditing];
        return;
    }
    const NSPoint p = event.locationInWindow;
    const NSRect field_in_window = [m_PathEditField convertRect:m_PathEditField.bounds toView:nil];
    if( NSPointInRect(p, field_in_window) )
        return;
    [self cancelInlinePathEditing];
}

- (void)beginInlinePathEditing
{
    if( !m_PathBarInteractive )
        return;
    if( self.searchPrompt != nil )
        return;

    [self removePathEditOutsideClickMonitorIfNeeded];

    [m_PathTextView clearHover];
    m_PathEditField.stringValue = m_LastFullPathForEditing ?: @"";
    m_PathTextView.hidden = true;
    m_PathEditField.hidden = false;
    [self.window makeFirstResponder:m_PathEditField];
    [m_PathEditField.currentEditor setSelectedRange:NSMakeRange(0, m_PathEditField.stringValue.length)];
    if( auto *const editor = nc::objc_cast<NSTextView>(m_PathEditField.currentEditor) ) {
        NSColor *const tc = m_Active ? m_Theme->ActiveTextColor() : m_Theme->TextColor();
        NSColor *const accent = m_Theme->PathAccentColor();
        editor.insertionPointColor = tc;
        editor.selectedTextAttributes =
            @{NSBackgroundColorAttributeName: accent ?: NSColor.selectedTextBackgroundColor};
    }

    __weak NCPanelViewHeader *weak_header = self;
    m_PathEditOutsideClickMonitor =
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown handler:^NSEvent *(NSEvent *event) {
            NCPanelViewHeader *const h = weak_header;
            if( !h || h->m_PathEditField.hidden )
                return event;
            [h handleOutsideMouseDownWhilePathEditing:event];
            return event;
        }];
}

- (void)setupAppearance
{
    NSFont *const font = m_Theme->Font();
    m_PathTextView.font = font;
    m_PathEditField.font = font;
    m_SearchTextField.font = font;
    m_SearchMatchesField.font = font;

    m_SeparatorLine.borderColor = m_Theme->SeparatorColor();

    const bool active = m_Active;
    m_Background = active ? m_Theme->ActiveBackgroundColor() : m_Theme->InactiveBackgroundColor();

    NSColor *text_color = active ? m_Theme->ActiveTextColor() : m_Theme->TextColor();
    m_PathEditField.textColor = text_color;
    m_SearchTextField.textColor = text_color;
    m_SearchMatchesField.textColor = text_color;

    ChangeButtonAttrString(m_SortButton, text_color, font);
    m_SearchClearButton.contentTintColor = text_color;
    m_SearchMagGlassButton.contentTintColor = text_color;
    self.needsDisplay = true;
    [self updatePathBarHeightConstraints];

    [self refreshPathBarAttributedText];

    if( !m_PathEditField.hidden ) {
        if( auto *const editor = nc::objc_cast<NSTextView>(m_PathEditField.currentEditor) ) {
            editor.insertionPointColor = text_color;
            NSColor *const accent = m_Theme->PathAccentColor();
            editor.selectedTextAttributes =
                @{NSBackgroundColorAttributeName: accent ?: NSColor.selectedTextBackgroundColor};
        }
    }
}

- (void)refreshPathBarAttributedText
{
    [m_PathTextView clearHover];
    NSFont *const font = m_Theme->Font();
    NSColor *const text_color = m_Active ? m_Theme->ActiveTextColor() : m_Theme->TextColor();
    m_PathTextView.pathAccentColor = m_Theme->PathAccentColor();
    if( m_PathBarInteractive && !m_LastBreadcrumbs.empty() ) {
        NSMutableAttributedString *const as =
            PanelHeaderBuildInteractivePathAttributedString(m_LastBreadcrumbs, font, text_color);
        [m_PathTextView.textStorage setAttributedString:as];
        m_PathTextView.linkTextAttributes = @{
            NSForegroundColorAttributeName: text_color,
            NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone),
        };
        // selectable=YES forces NSTextView's text-cursor behavior over the whole path bar; keep NO and use copy:/menu.
        m_PathTextView.selectable = false;
    }
    else {
        NSMutableAttributedString *const as =
            PanelHeaderBuildPlainPathAttributedString(m_LastPlainPath ?: @"", font, text_color);
        [m_PathTextView.textStorage setAttributedString:as];
        m_PathTextView.linkTextAttributes = @{};
        m_PathTextView.selectable = false;
    }
    if( self.window != nil )
        [self.window invalidateCursorRectsForView:m_PathTextView];
}

- (void)setupLayout
{
    NSDictionary *views = NSDictionaryOfVariableBindings(m_PathArea,
                                                         m_SearchTextField,
                                                         m_SeparatorLine,
                                                         m_SearchMatchesField,
                                                         m_SearchClearButton,
                                                         m_SearchMagGlassButton,
                                                         m_SortButton,
                                                         m_BusyIndicator);
    [self addConstraints:[NSLayoutConstraint
                             constraintsWithVisualFormat:@"|-(==0)-[m_SortButton(==20)]-(==0)-[m_PathArea]-(==2)-|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_BusyIndicator]-(==2)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_SeparatorLine]-(0)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint
                             constraintsWithVisualFormat:@"|-(4)-[m_SearchMagGlassButton(==15)]-[m_SearchTextField]-[m_"
                                                         @"SearchMatchesField]-[m_SearchClearButton(==15)]-(4)-|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];

    [m_SearchTextField setContentHuggingPriority:NSLayoutPriorityDefaultLow
                                  forOrientation:NSLayoutConstraintOrientationHorizontal];

    [m_SearchMatchesField setContentHuggingPriority:NSLayoutPriorityRequired
                                     forOrientation:NSLayoutConstraintOrientationHorizontal];

    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_SeparatorLine(==1)]-(==0)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_BusyIndicator]-(==2)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];

    [self addConstraint:LayoutConstraintForCenteringViewVertically(m_PathArea, self)];
    // m_PathArea has no intrinsic height; keep path row height in sync with the adaptive strip height.
    m_PathAreaHeightConstraint = [m_PathArea.heightAnchor constraintEqualToConstant:1.0];
    [NSLayoutConstraint activateConstraints:@[
        m_PathAreaHeightConstraint,
        [m_PathArea.topAnchor constraintGreaterThanOrEqualToAnchor:self.topAnchor],
        [m_PathArea.bottomAnchor constraintLessThanOrEqualToAnchor:self.bottomAnchor],
    ]];
    [self addConstraint:LayoutConstraintForCenteringViewVertically(m_SearchTextField, self)];
    [self addConstraint:LayoutConstraintForCenteringViewVertically(m_SearchMagGlassButton, self)];
    [self addConstraint:LayoutConstraintForCenteringViewVertically(m_SearchMatchesField, self)];
    [self addConstraint:LayoutConstraintForCenteringViewVertically(m_SearchClearButton, self)];
    [self addConstraint:LayoutConstraintForCenteringViewVertically(m_SortButton, self)];
}

- (void)updatePathBarHeightConstraints
{
    const CGFloat row_h = NCPanelPathBarAdaptiveRowHeight(m_Theme ? m_Theme->Font() : nil, self);
    if( m_PathAreaHeightConstraint )
        m_PathAreaHeightConstraint.constant = row_h;
    if( m_StripHeightConstraint )
        m_StripHeightConstraint.constant = row_h;
}

- (BOOL)isOpaque
{
    return true;
}

- (BOOL)canDrawSubviewsIntoLayer
{
    return true;
}

- (void)drawRect:(NSRect) [[maybe_unused]] dirtyRect
{
    if( m_Background && m_Background != NSColor.clearColor ) {
        CGContextRef context = NSGraphicsContext.currentContext.CGContext;
        CGContextSetFillColorWithColor(context, m_Background.CGColor);
        CGContextFillRect(context, NSRectToCGRect(self.bounds));
    }
    else {
        NSDrawWindowBackground(self.bounds);
    }
}

- (void)setPath:(NSString *)_path
{
    [self setPlainHeaderPath:_path];
}

- (void)setPlainHeaderPath:(NSString *)_path
{
    [self endInlinePathEditingUI];
    m_PathBarInteractive = false;
    m_LastBreadcrumbs.clear();
    m_LastFullPathForEditing = nil;
    m_LastPlainPath = [_path copy] ?: @"";
    [self refreshPathBarAttributedText];
}

- (void)setInteractiveBreadcrumbs:(const std::vector<PanelHeaderBreadcrumb> &)_breadcrumbs
               fullPathForEditing:(NSString *)_full_path_for_editing
{
    [self endInlinePathEditingUI];
    m_PathBarInteractive = !_breadcrumbs.empty();
    m_LastBreadcrumbs = _breadcrumbs;
    m_LastFullPathForEditing = [_full_path_for_editing copy];
    m_LastPlainPath = nil;
    [self refreshPathBarAttributedText];
}

- (void)endInlinePathEditingUI
{
    [self removePathEditOutsideClickMonitorIfNeeded];
    m_PathTextView.hidden = false;
    m_PathEditField.hidden = true;
}

- (void)commitInlinePathEditing
{
    NSString *const raw =
        [[m_PathEditField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if( raw.length > 0 && m_PathCommitCallback ) {
        // Keep the editor visible until panel data really updates the path header. This avoids a brief fallback to
        // stale breadcrumbs between Enter and async GoToDir completion.
        const uint64_t seq = ++m_PathEditCommitSeq;
        m_PathCommitCallback(raw);
        if( self.window && self.defaultResponder )
            [self.window makeFirstResponder:self.defaultResponder];

        // If navigation fails (or takes too long), don't leave the editor stuck on screen indefinitely.
        __weak NCPanelViewHeader *weak_self = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, static_cast<int64_t>(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NCPanelViewHeader *const strong_self = weak_self;
            if( !strong_self )
                return;
            if( strong_self->m_PathEditCommitSeq != seq )
                return;
            if( strong_self->m_PathEditField.hidden )
                return;
            [strong_self endInlinePathEditingUI];
        });
        return;
    }
    [self endInlinePathEditingUI];
    if( self.window && self.defaultResponder )
        [self.window makeFirstResponder:self.defaultResponder];
}

- (void)cancelInlinePathEditing
{
    [self endInlinePathEditingUI];
    if( self.window && self.defaultResponder )
        [self.window makeFirstResponder:self.defaultResponder];
}

- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex
{
    (void)textView;
    (void)charIndex;
    if( auto url = nc::objc_cast<NSURL>(link) ) {
        if( ![url.scheme isEqualToString:@"x-nc-panel-path"] )
            return NO;
        NSString *p = url.path;
        if( !p.length )
            return NO;
        const char *const raw = p.UTF8String;
        if( !raw )
            return NO;
        const std::string utf8{raw};
        if( m_PathNavigateCallback )
            m_PathNavigateCallback(utf8);
        return YES;
    }
    return NO;
}

- (nullable NSMenu *)textView:(NSTextView *)textView
                         menu:(NSMenu *)menu
                      forEvent:(NSEvent *)event
                       atIndex:(NSUInteger)charIndex
{
    (void)charIndex;
    // AppKit augments NSTextView context menus (Services, "Open", "Show in Finder", etc.). This delegate hook is the
    // supported way to replace that menu with our path-bar-specific items only.
    if( textView != m_PathTextView || !self.pathBarContextMenuAction )
        return menu;
    const NSPoint p = [textView convertPoint:event.locationInWindow fromView:nil];
    NSString *const path = [self posixPathForPathBarContextMenuAtPoint:p];
    if( path.length == 0 )
        return menu;
    return [self pathBarContextMenuForPOSIXPath:path];
}

- (nullable NSString *)posixPathForPathBarContextMenuAtPoint:(NSPoint)pInTextViewCoords
{
    if( m_PathTextView.textStorage.length == 0 )
        return nil;
    if( ![m_PathTextView nc_pointIsInsideLaidOutPathGlyphs:pInTextViewCoords] )
        return nil;
    if( !m_PathBarInteractive ) {
        NSString *const s = m_LastPlainPath ?: @"";
        return s.length ? s : nil;
    }
    const NSUInteger len = m_PathTextView.textStorage.length;
    NSUInteger idx = [m_PathTextView characterIndexForInsertionAtPoint:pInTextViewCoords];
    if( idx >= len ) {
        NSString *const full = m_LastFullPathForEditing ?: @"";
        return full.length ? full : nil;
    }
    NSRange link_range = {};
    id link = [m_PathTextView.textStorage attribute:NSLinkAttributeName atIndex:idx effectiveRange:&link_range];
    if( link && NSLocationInRange(idx, link_range) ) {
        if( auto url = nc::objc_cast<NSURL>(link) ) {
            if( [url.scheme isEqualToString:@"x-nc-panel-path"] ) {
                NSString *const p = url.path;
                return p.length ? p : nil;
            }
        }
        return nil;
    }
    NSString *const full = m_LastFullPathForEditing ?: @"";
    return full.length ? full : nil;
}

- (NSMenu *)pathBarContextMenuForPOSIXPath:(NSString *)path
{
    NSMenu *const menu = [[NSMenu alloc] initWithTitle:@""];
    auto add = ^(NSString *title, NCPanelPathBarContextCommand cmd) {
        NSMenuItem *const it = [[NSMenuItem alloc] initWithTitle:title
                                                          action:@selector(handlePathBarContextMenuItem:)
                                                   keyEquivalent:@""];
        it.target = self;
        it.tag = cmd;
        it.representedObject = path;
        [menu addItem:it];
    };
    add(NSLocalizedString(@"Open", @"Path bar context: open directory in panel"), NCPanelPathBarContextCommandOpen);
    add(NSLocalizedString(@"Open in New Tab", @"Path bar context: open directory in a new tab"),
        NCPanelPathBarContextCommandOpenInNewTab);
    [menu addItem:[NSMenuItem separatorItem]];
    add(NSLocalizedString(@"Copy Path", @"Path bar context: copy POSIX path"), NCPanelPathBarContextCommandCopyPath);
    return menu;
}

- (void)handlePathBarContextMenuItem:(NSMenuItem *)item
{
    NSString *const path = nc::objc_cast<NSString>(item.representedObject);
    if( path.length == 0 || !self.pathBarContextMenuAction )
        return;
    self.pathBarContextMenuAction(path, static_cast<NCPanelPathBarContextCommand>(item.tag));
}

- (BOOL)control:(NSControl *)control
              textView:(NSTextView *) [[maybe_unused]] fieldEditor
       doCommandBySelector:(SEL)commandSelector
{
    if( control == m_PathEditField && commandSelector == @selector(insertNewline:) ) {
        [self commitInlinePathEditing];
        return YES;
    }
    return NO;
}

- (void)setupBindings
{
    static const auto isnil = @{NSValueTransformerNameBindingOption: NSIsNilTransformerName};
    static const auto isnotnil = @{NSValueTransformerNameBindingOption: NSIsNotNilTransformerName};
    [m_SearchMagGlassButton bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnil];
    [m_SearchTextField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnil];
    [m_SearchMatchesField bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnil];
    [m_SearchClearButton bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnil];
    [m_PathArea bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnotnil];
    [m_SortButton bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnotnil];
    [m_BusyIndicator bind:@"hidden" toObject:self withKeyPath:@"searchPrompt" options:isnotnil];
}

- (void)removeBindings
{
    [m_SearchMagGlassButton unbind:@"hidden"];
    [m_SearchTextField unbind:@"hidden"];
    [m_SearchMatchesField unbind:@"hidden"];
    [m_SearchClearButton unbind:@"hidden"];
    [m_PathArea unbind:@"hidden"];
    [m_SortButton unbind:@"hidden"];
    [m_BusyIndicator unbind:@"hidden"];
}

- (void)viewDidMoveToSuperview
{
    if( self.superview )
        [self setupBindings];
    else {
        [self removePathEditOutsideClickMonitorIfNeeded];
        [self removeBindings];
    }
}

- (void)setSearchRequestChangeCallback:(std::function<void(NSString *)>)searchRequestChangeCallback
{
    m_SearchRequestChangeCallback = std::move(searchRequestChangeCallback);
}

- (std::function<void(NSString *)>)searchRequestChangeCallback
{
    return m_SearchRequestChangeCallback;
}

- (NSString *)searchPrompt
{
    return m_SearchPrompt;
}

- (void)setSearchPrompt:(NSString *)searchPrompt
{
    if( (m_SearchPrompt == searchPrompt) || (!m_SearchPrompt && !searchPrompt.length) )
        return;

    [self willChangeValueForKey:@"searchPrompt"];
    m_SearchPrompt = searchPrompt.length ? searchPrompt : nil;
    [self didChangeValueForKey:@"searchPrompt"];

    m_SearchTextField.stringValue = m_SearchPrompt ? m_SearchPrompt : @"";
    [m_SearchTextField invalidateIntrinsicContentSize];
    [self layout];
}

- (int)searchMatches
{
    return m_SearchMatchesField.intValue;
}

- (void)setSearchMatches:(int)searchMatches
{
    m_SearchMatchesField.intValue = searchMatches;
}

- (void)onSearchFieldDiscardButton:(id) [[maybe_unused]] _sender
{
    self.searchPrompt = nil;
    [self.window makeFirstResponder:self.defaultResponder];
    if( m_SearchRequestChangeCallback )
        m_SearchRequestChangeCallback(nil);
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    if( obj.object == m_SearchTextField ) {
        NSString *v = m_SearchTextField.stringValue;
        if( v.length > 0 ) {
            if( m_SearchRequestChangeCallback )
                m_SearchRequestChangeCallback(v);
        }
        else
            [self onSearchFieldDiscardButton:m_SearchTextField];
    }
}

- (void)onSearchFieldAction:(id) [[maybe_unused]] _sender
{
}

- (void)onSortButtonAction:(id) [[maybe_unused]] _sender
{
    if( !self.sortMenuPopup ) {
        NSNib *nib = [[NSNib alloc] initWithNibNamed:@"PanelViewHeaderSortPopup" bundle:nil];
        [nib instantiateWithOwner:self topLevelObjects:nil];
    }

    for( NSMenuItem *i in self.sortMenuPopup.itemArray ) {
        if( i.action == @selector(onSortPopupMenuSortByClicked:) )
            i.state = i.tag == m_SortMode.sort ? NSControlStateValueOn : NSControlStateValueOff;
        else if( i.action == @selector(onSortPopupMenuOptionsClicked:) )
            switch( i.tag ) {
                case 1:
                    i.state = m_SortMode.sep_dirs ? NSControlStateValueOn : NSControlStateValueOff;
                    break;
                case 2:
                    i.state = m_SortMode.extensionless_dirs ? NSControlStateValueOn : NSControlStateValueOff;
                    break;
                case 3:
                    i.state = m_SortMode.collation == data::SortMode::Collation::Natural ? NSControlStateValueOn
                                                                                         : NSControlStateValueOff;
                    break;
                case 4:
                    i.state = m_SortMode.collation == data::SortMode::Collation::CaseInsensitive
                                  ? NSControlStateValueOn
                                  : NSControlStateValueOff;
                    break;
                case 5:
                    i.state = m_SortMode.collation == data::SortMode::Collation::CaseSensitive ? NSControlStateValueOn
                                                                                               : NSControlStateValueOff;
                    break;
                default:
                    /* do nothing */;
            }
    }

    [self.sortMenuPopup popUpMenuPositioningItem:nil
                                      atLocation:NSMakePoint(m_SortButton.bounds.size.width, 0)
                                          inView:m_SortButton];
}

- (void)setSortMode:(data::SortMode)_mode
{
    if( m_SortMode == _mode )
        return;

    m_SortMode = _mode;
    ChangeAttributedTitle(m_SortButton, SortLetter(_mode));
}

- (IBAction)onSortPopupMenuSortByClicked:(id)sender
{
    if( auto item = nc::objc_cast<NSMenuItem>(sender) ) {
        const auto new_sort_mode = static_cast<data::SortMode::Mode>(item.tag);
        if( !data::SortMode::validate(new_sort_mode) )
            return;

        auto proposed = m_SortMode;
        proposed.sort = new_sort_mode;

        if( proposed != m_SortMode && m_SortModeChangeCallback )
            m_SortModeChangeCallback(proposed);
    }
}

- (IBAction)onSortPopupMenuOptionsClicked:(id)sender
{
    if( auto item = nc::objc_cast<NSMenuItem>(sender) ) {
        auto proposed = m_SortMode;
        switch( item.tag ) {
            case 1:
                proposed.sep_dirs = !proposed.sep_dirs;
                break;
            case 2:
                proposed.extensionless_dirs = !proposed.extensionless_dirs;
                break;
            case 3:
                proposed.collation = data::SortMode::Collation::Natural;
                break;
            case 4:
                proposed.collation = data::SortMode::Collation::CaseInsensitive;
                break;
            case 5:
                proposed.collation = data::SortMode::Collation::CaseSensitive;
                break;
            default:
                /* do nothing */;
        }

        if( proposed != m_SortMode && m_SortModeChangeCallback )
            m_SortModeChangeCallback(proposed);
    }
}

- (NSProgressIndicator *)busyIndicator
{
    return m_BusyIndicator;
}

- (void)setActive:(bool)active
{
    if( active == m_Active )
        return;
    m_Active = active;

    [self setupAppearance];
}

- (bool)active
{
    return m_Active;
}

- (void)cancelOperation:(id)_sender
{
    if( m_SearchPrompt != nil ) {
        [self onSearchFieldDiscardButton:m_SearchTextField];
        return;
    }

    if( !m_PathEditField.hidden ) {
        [self cancelInlinePathEditing];
        return;
    }

    [super cancelOperation:_sender];
}

@end

static NSURL *PanelHeaderMakeLinkURLFromVFSPath(const std::string &_path) noexcept
{
    if( _path.empty() || _path.front() != '/' )
        return nil;
    NSURLComponents *const c = [[NSURLComponents alloc] init];
    c.scheme = @"x-nc-panel-path";
    c.path = [NSString stringWithUTF8String:_path.c_str()];
    return c.URL;
}

static NSMutableAttributedString *PanelHeaderBuildInteractivePathAttributedString(const std::vector<PanelHeaderBreadcrumb> &_crumbs,
                                                                                NSFont *_font,
                                                                                NSColor *_text_color)
{
    NSMutableParagraphStyle *const paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByTruncatingHead;
    paragraph.alignment = NSTextAlignmentCenter;

    NSDictionary *const base_attrs = @{
        NSFontAttributeName: _font,
        NSForegroundColorAttributeName: _text_color,
        NSParagraphStyleAttributeName: paragraph,
    };

    NSColor *const sep_color = [_text_color colorWithAlphaComponent:0.55];
    NSDictionary *const sep_attrs = @{
        NSFontAttributeName: _font,
        NSForegroundColorAttributeName: sep_color,
        NSParagraphStyleAttributeName: paragraph,
    };

    auto *const result = [[NSMutableAttributedString alloc] init];
    bool first = true;

    // Find last non-empty crumb index for marking the current segment.
    NSInteger last_crumb_idx = -1;
    for( NSInteger i = static_cast<NSInteger>(_crumbs.size()) - 1; i >= 0; --i ) {
        if( _crumbs[static_cast<size_t>(i)].label.length ) {
            last_crumb_idx = i;
            break;
        }
    }

    NSInteger crumb_idx = -1;
    for( const auto &crumb : _crumbs ) {
        ++crumb_idx;
        if( !crumb.label.length )
            continue;
        if( !first )
            [result appendAttributedString:[[NSAttributedString alloc] initWithString:@" › " attributes:sep_attrs]];
        first = false;

        const bool is_last = (crumb_idx == last_crumb_idx);
        if( crumb.navigate_to_vfs_path ) {
            NSURL *const url = PanelHeaderMakeLinkURLFromVFSPath(*crumb.navigate_to_vfs_path);
            if( url ) {
                NSMutableDictionary *const attrs = [base_attrs mutableCopy];
                attrs[NSLinkAttributeName] = url;
                attrs[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleNone);
                if( is_last )
                    attrs[NCPanelPathBarCurrentCrumbAttributeName] = @YES;
                [result appendAttributedString:[[NSAttributedString alloc] initWithString:crumb.label attributes:attrs]];
            }
            else {
                NSMutableDictionary *const attrs = [base_attrs mutableCopy];
                if( is_last )
                    attrs[NCPanelPathBarCurrentCrumbAttributeName] = @YES;
                [result appendAttributedString:[[NSAttributedString alloc] initWithString:crumb.label attributes:attrs]];
            }
        }
        else {
            NSMutableDictionary *const attrs = [base_attrs mutableCopy];
            if( is_last )
                attrs[NCPanelPathBarCurrentCrumbAttributeName] = @YES;
            [result appendAttributedString:[[NSAttributedString alloc] initWithString:crumb.label attributes:attrs]];
        }
    }
    return result;
}

static NSMutableAttributedString *PanelHeaderBuildPlainPathAttributedString(NSString *_path, NSFont *_font, NSColor *_text_color)
{
    NSMutableParagraphStyle *const paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByTruncatingHead;
    paragraph.alignment = NSTextAlignmentCenter;
    NSDictionary *const attrs = @{
        NSFontAttributeName: _font,
        NSForegroundColorAttributeName: _text_color,
        NSParagraphStyleAttributeName: paragraph,
    };
    return [[NSMutableAttributedString alloc] initWithString:_path ?: @"" attributes:attrs];
}

static void ChangeButtonAttrString(NSButton *_button, NSColor *_new_color, NSFont *_font)
{
    NSMutableAttributedString *const sort_title =
        [[NSMutableAttributedString alloc] initWithAttributedString:_button.attributedTitle];
    const unsigned long length = sort_title.length;
    [sort_title addAttribute:NSForegroundColorAttributeName value:_new_color range:NSMakeRange(0, length)];
    [sort_title addAttribute:NSFontAttributeName value:_font range:NSMakeRange(0, length)];
    _button.attributedTitle = sort_title;
}

static void ChangeAttributedTitle(NSButton *_button, NSString *_new_text)
{
    const auto title = [[NSMutableAttributedString alloc] initWithAttributedString:_button.attributedTitle];
    [title replaceCharactersInRange:NSMakeRange(0, title.length) withString:_new_text];
    _button.attributedTitle = title;
}

static NSString *SortLetter(data::SortMode _mode) noexcept
{
    switch( _mode.sort ) {
        case data::SortMode::SortByName:
            return @"n";
        case data::SortMode::SortByNameRev:
            return @"N";
        case data::SortMode::SortByExt:
            return @"e";
        case data::SortMode::SortByExtRev:
            return @"E";
        case data::SortMode::SortBySize:
            return @"s";
        case data::SortMode::SortBySizeRev:
            return @"S";
        case data::SortMode::SortByModTime:
            return @"m";
        case data::SortMode::SortByModTimeRev:
            return @"M";
        case data::SortMode::SortByBirthTime:
            return @"b";
        case data::SortMode::SortByBirthTimeRev:
            return @"B";
        case data::SortMode::SortByAddTime:
            return @"a";
        case data::SortMode::SortByAddTimeRev:
            return @"A";
        case data::SortMode::SortByAccessTime:
            return @"x";
        case data::SortMode::SortByAccessTimeRev:
            return @"X";
        default:
            return @"?";
    }
}

static bool IsDark(NSColor *_color)
{
    const auto c = [_color colorUsingColorSpace:NSColorSpace.genericRGBColorSpace];
    return c.brightnessComponent < 0.60;
}

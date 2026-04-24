// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#import "NCPanelPathBarView.h"
#import "NCPanelBreadcrumbsView.h"

static const CGFloat kNCPanelPathBarFullPathHorizontalInset = 6.;
static const CGFloat kNCPathScrollFallbackLinePixels = 16.;

@interface NCPathActiveLayoutManager : NSLayoutManager
@end

@implementation NCPathActiveLayoutManager
- (BOOL)layoutManagerOwnsFirstResponderInWindow:(NSWindow *)window
{
    (void)window;
    return true;
}
@end

@interface NCPathScrollView : NSScrollView
@end

@implementation NCPathScrollView

- (void)scrollWheel:(NSEvent *)event
{
    CGFloat hDelta;
    if( event.hasPreciseScrollingDeltas ) {
        const CGFloat dx = event.scrollingDeltaX;
        const CGFloat dy = event.scrollingDeltaY;
        hDelta = (fabs(dx) >= fabs(dy)) ? dx : dy;
    }
    else {
        const CGFloat lineStep =
            (self.horizontalLineScroll > 0.) ? self.horizontalLineScroll : kNCPathScrollFallbackLinePixels;
        hDelta = event.deltaY * lineStep;
    }

    if( hDelta == 0.0 )
        return;

    NSClipView *const clip = self.contentView;
    NSPoint origin = clip.bounds.origin;
    const CGFloat maxX = MAX(0.0, NSWidth(self.documentView.frame) - NSWidth(clip.bounds));
    origin.x = MAX(0.0, MIN(origin.x - hDelta, maxX));
    [clip scrollToPoint:origin];
    [self reflectScrolledClipView:clip];
}

@end

@implementation NCPanelPathBarView {
    NCPanelBreadcrumbsView *m_Breadcrumbs;
    NCPathScrollView *m_PathScrollView;
    NSTextView *m_PathTextView;
}

@synthesize breadcrumbsView = m_Breadcrumbs;
@synthesize pathTextView = m_PathTextView;
@synthesize fullPathEditActive = _fullPathEditActive;
@synthesize onCancelFullPathEdit = _onCancelFullPathEdit;

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        self.clipsToBounds = YES;

        m_Breadcrumbs = [[NCPanelBreadcrumbsView alloc] initWithFrame:NSZeroRect];
        m_Breadcrumbs.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:m_Breadcrumbs];

        m_PathScrollView = [[NCPathScrollView alloc] initWithFrame:NSZeroRect];
        m_PathScrollView.translatesAutoresizingMaskIntoConstraints = NO;
        m_PathScrollView.hasHorizontalScroller = NO;
        m_PathScrollView.hasVerticalScroller = NO;
        m_PathScrollView.autohidesScrollers = NO;
        m_PathScrollView.borderType = NSNoBorder;
        m_PathScrollView.drawsBackground = NO;
        m_PathScrollView.hidden = YES;
        [self addSubview:m_PathScrollView];

        m_PathTextView = [[NSTextView alloc] initWithFrame:NSZeroRect];
        m_PathTextView.editable = NO;
        m_PathTextView.selectable = YES;
        m_PathTextView.richText = NO;
        m_PathTextView.drawsBackground = NO;
        m_PathTextView.focusRingType = NSFocusRingTypeNone;
        m_PathTextView.textContainer.widthTracksTextView = NO;
        m_PathTextView.textContainer.containerSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
        m_PathTextView.textContainer.lineFragmentPadding = 0.0;
        [m_PathTextView.textContainer replaceLayoutManager:[[NCPathActiveLayoutManager alloc] init]];
        m_PathTextView.horizontallyResizable = YES;
        m_PathTextView.verticallyResizable = NO;
        m_PathTextView.autoresizingMask = NSViewNotSizable;
        m_PathTextView.delegate = self;
        m_PathScrollView.documentView = m_PathTextView;
        {
            NSLayoutManager *const lm = [[NSLayoutManager alloc] init];
            const CGFloat defaultLine = [lm defaultLineHeightForFont:[NSFont systemFontOfSize:13.]];
            m_PathScrollView.horizontalLineScroll = defaultLine;
        }

        self.fullPathEditActive = false;

        [NSLayoutConstraint activateConstraints:@[
            [m_Breadcrumbs.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [m_Breadcrumbs.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [m_Breadcrumbs.topAnchor constraintEqualToAnchor:self.topAnchor],
            [m_Breadcrumbs.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [m_PathScrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [m_PathScrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [m_PathScrollView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [m_PathScrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
    }
    return self;
}

- (void)syncPathTextViewVerticalAlignmentWithFont:(NSFont *)font
{
    NSFont *const f = font ?: [NSFont systemFontOfSize:13.];
    NSLayoutManager *const lm = [[NSLayoutManager alloc] init];
    const CGFloat lineH = [lm defaultLineHeightForFont:f];
    const CGFloat viewH = NSHeight(m_PathScrollView.contentView.bounds);
    const CGFloat insetY = (viewH > lineH) ? floor((viewH - lineH) * 0.5) : 0.0;
    m_PathTextView.textContainerInset = NSMakeSize(kNCPanelPathBarFullPathHorizontalInset, insetY);
    if( lineH > 0. )
        m_PathScrollView.horizontalLineScroll = lineH;
    [self resizeTextViewToContent];
}

- (void)resizeTextViewToContent
{
    [m_PathTextView.layoutManager ensureLayoutForTextContainer:m_PathTextView.textContainer];
    const NSRect used = [m_PathTextView.layoutManager usedRectForTextContainer:m_PathTextView.textContainer];
    const CGFloat clipH = NSHeight(m_PathScrollView.contentView.bounds);
    const CGFloat clipW = NSWidth(m_PathScrollView.contentView.bounds);
    const CGFloat insetW = m_PathTextView.textContainerInset.width;
    const CGFloat insetH = m_PathTextView.textContainerInset.height;
    const CGFloat contentW = MAX(clipW, ceil(used.size.width) + insetW * 2.0);
    const CGFloat contentH = MAX(clipH, ceil(used.size.height) + insetH * 2.0);
    m_PathTextView.frame = NSMakeRect(0.0, 0.0, contentW, contentH);
}

- (void)layout
{
    [super layout];
    if( self.fullPathEditActive )
        [self resizeTextViewToContent];
}

- (void)enterFullPathEditWithString:(NSString *)path font:(NSFont *)font textColor:(NSColor *)textColor
{
    NSFont *const f = font ?: [NSFont systemFontOfSize:13.];
    NSColor *const c = textColor ?: NSColor.textColor;

    m_PathTextView.font = f;
    m_PathTextView.textColor = c;
    m_PathTextView.string = path ?: @"";

    [self syncPathTextViewVerticalAlignmentWithFont:f];

    m_Breadcrumbs.hidden = YES;
    m_PathScrollView.hidden = NO;
    self.fullPathEditActive = true;

    [self.window makeFirstResponder:m_PathTextView];
    [m_PathTextView selectAll:nil];

    if( c.type == NSColorTypeComponentBased ) {
        NSColor *const rgb = [c colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        if( rgb != nil ) {
            CGFloat r = 0., g = 0., b = 0., a = 0.;
            [rgb getRed:&r green:&g blue:&b alpha:&a];
            if( 0.299 * r + 0.587 * g + 0.114 * b > 0.85 ) {
                m_PathTextView.selectedTextAttributes = @{
                    NSBackgroundColorAttributeName: NSColor.textBackgroundColor,
                    NSForegroundColorAttributeName: NSColor.controlTextColor,
                };
                m_PathTextView.insertionPointColor = c;
            }
        }
    }

    [m_PathTextView scrollRangeToVisible:NSMakeRange(m_PathTextView.string.length, 0)];
}

- (void)exitFullPathEdit
{
    m_Breadcrumbs.hidden = NO;
    m_PathScrollView.hidden = YES;
    self.fullPathEditActive = false;
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    bool handled = false;
    if( textView == m_PathTextView &&
        (commandSelector == @selector(cancelOperation:) || commandSelector == @selector(insertNewline:)) ) {
        if( self.onCancelFullPathEdit )
            self.onCancelFullPathEdit();
        handled = true;
    }
    return handled;
}

@end

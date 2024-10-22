// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FontCache.h>
#include "View.h"
#include "Screen.h"
#include "Settings.h"
#include "ScrollView.h"
#include "FlippableHolder.h"
#include <cmath>

using namespace nc;
using namespace nc::term;

static const NSEdgeInsets g_Insets = {2., 5., 2., 5.};

@implementation NCTermScrollView {
    NCTermView *m_View;
    NCTermFlippableHolder *m_ViewHolder;
    std::unique_ptr<term::Screen> m_Screen;
    std::shared_ptr<nc::term::Settings> m_Settings;
    std::function<void(int sx, int sy)> m_OnScreenResized;
    int m_SettingsNotificationTicket;
    bool m_Overlapped;
    double m_NonOverlappedHeight;
    NSTrackingArea *m_TrackingArea;
}

@synthesize view = m_View;
@synthesize onScreenResized = m_OnScreenResized;
@synthesize customCursor;

- (id)initWithFrame:(NSRect)frameRect attachToTop:(bool)top settings:(std::shared_ptr<nc::term::Settings>)settings
{
    assert(settings);
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_Overlapped = false;
        m_NonOverlappedHeight = 0.;
        self.customCursor = NSCursor.IBeamCursor;

        auto rc = self.contentView.bounds;
        m_Settings = settings;
        m_View = [[NCTermView alloc] initWithFrame:rc];
        m_View.settings = settings;
        m_ViewHolder = [[NCTermFlippableHolder alloc] initWithFrame:rc andView:m_View beFlipped:top];
        self.documentView = m_ViewHolder;
        self.hasVerticalScroller = !settings->HideScrollbar();
        self.borderType = NSNoBorder;
        self.verticalScrollElasticity = NSScrollElasticityNone;
        self.scrollsDynamically = true;
        self.contentView.copiesOnScroll = false;
        self.contentView.canDrawConcurrently = false;
        self.contentView.drawsBackground = true;
        self.contentView.backgroundColor = m_Settings->BackgroundColor();
        self.drawsBackground = true;
        self.backgroundColor = m_Settings->BackgroundColor();
        self.verticalLineScroll = m_View.charHeight;

        m_Screen = std::make_unique<term::Screen>(floor(rc.size.width / m_View.charWidth),
                                                  floor(rc.size.height / m_View.charHeight));

        [m_View AttachToScreen:m_Screen.get()];

        [self addConstraints:[NSLayoutConstraint
                                 constraintsWithVisualFormat:@"H:|-0-[m_ViewHolder(>=100)]-0-|"
                                                     options:0
                                                     metrics:nil
                                                       views:NSDictionaryOfVariableBindings(m_ViewHolder)]];

        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];

        __weak NCTermScrollView *weak_self = self;
        m_SettingsNotificationTicket = m_Settings->StartChangesObserving([weak_self] {
            if( auto strong_self = weak_self )
                [strong_self onSettingsChanged];
        });

        [self updateTrackingAreas];
    }
    return self;
}

- (id)initWithFrame:(NSRect)frameRect attachToTop:(bool)top
{
    return [self initWithFrame:frameRect attachToTop:top settings:DefaultSettings::SharedDefaultSettings()];
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)cursorUpdate:(NSEvent *) [[maybe_unused]] _event
{
    if( !m_TrackingArea ) {
        [super cursorUpdate:_event];
        return;
    }

    if( m_Overlapped ) {
        const NSPoint global_mouse_location = NSEvent.mouseLocation;
        const NSPoint window_mouse_location = [self.view.window convertPointFromScreen:global_mouse_location];
        const NSPoint local_mouse_location = [self convertPoint:window_mouse_location fromView:nil];
        const NSRect tracking_rect = m_TrackingArea.rect;
        if( NSPointInRect(local_mouse_location, tracking_rect) ) {
            [self.customCursor set];
        }
        else {
            [super cursorUpdate:_event];
        }
    }
    else {
        [self.customCursor set];
    }
}

- (term::Screen &)screen
{
    assert(m_Screen);
    return *m_Screen;
}

- (void)onSettingsChanged
{
    self.contentView.backgroundColor = m_Settings->BackgroundColor();
    self.backgroundColor = m_Settings->BackgroundColor();
    if( m_View.font != m_Settings->Font() ) {
        m_View.font = m_Settings->Font();
        [self frameDidChange]; // handle with care - it will cause geometry recalculating
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    const auto context = NSGraphicsContext.currentContext.CGContext;
    CGContextSetFillColorWithColor(context, m_Settings->BackgroundColor().CGColor);
    CGContextFillRect(context, NSRectToCGRect(NSIntersectionRect(dirtyRect, self.bounds)));
}

- (void)frameDidChange
{
    if( m_Screen == nullptr )
        return;

    const auto full_size = self.contentView.frame.size;

    const int sy = static_cast<int>(std::floor(full_size.height / m_View.charHeight));
    const int sx = static_cast<int>(std::floor(full_size.width / m_View.charWidth));

    if( sx != m_Screen->Width() || sy != m_Screen->Height() ) {
        {
            auto lock = m_Screen->AcquireLock();
            m_Screen->ResizeScreen(sx, sy);
        }

        if( m_OnScreenResized )
            m_OnScreenResized(sx, sy);
    }

    [self tile];
    [m_View adjustSizes:true];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    // is this code necessary?
    NSRect scrollRect;
    scrollRect = [self documentVisibleRect];
    scrollRect.origin.y += std::floor(theEvent.deltaY) * self.verticalLineScroll * (m_ViewHolder.isFlipped ? -1 : 1);
    [static_cast<NSView *>(self.documentView) scrollRectToVisible:scrollRect];
}

- (void)setScrollerStyle:(NSScrollerStyle)scrollerStyle
{
    [super setScrollerStyle:scrollerStyle];
    [self frameDidChange];
}

- (void)tile
{
    [super tile];

    auto rc = self.contentView.frame;
    rc.origin.y += g_Insets.top;
    rc.origin.x += g_Insets.left;
    rc.size.height -= g_Insets.top + g_Insets.bottom;
    rc.size.width -= g_Insets.left + g_Insets.right;

    const auto rest = rc.size.height - (std::floor(rc.size.height / m_View.charHeight) * m_View.charHeight);
    rc.size.height -= rest;

    self.contentView.frame = rc;
}

- (NSEdgeInsets)viewInsets
{
    return g_Insets;
}

- (void)mouseDown:(NSEvent *)_event
{
    [m_View mouseDown:_event];
}

- (bool)overlapped
{
    return m_Overlapped;
}

- (void)setOverlapped:(bool)_overlapped
{
    if( m_Overlapped == _overlapped ) {
        return;
    }
    m_Overlapped = _overlapped;
    if( m_TrackingArea ) {
        [self removeTrackingArea:m_TrackingArea];
        m_TrackingArea = nil;
    }
    [self updateTrackingAreas];
}

- (double)nonOverlappedHeight
{
    return m_NonOverlappedHeight;
}

- (void)setNonOverlappedHeight:(double)_height
{
    if( m_NonOverlappedHeight == _height ) {
        return;
    }

    m_NonOverlappedHeight = _height;
    [self updateTrackingAreas];
}

- (void)updateTrackingAreas
{
    [super updateTrackingAreas];

    if( m_Overlapped ) {
        if( m_TrackingArea ) {
            [self removeTrackingArea:m_TrackingArea];
            m_TrackingArea = nil;
        }

        if( m_NonOverlappedHeight > 0. ) {
            const NSTrackingAreaOptions tracking_flags = NSTrackingActiveInKeyWindow | NSTrackingCursorUpdate;
            const NSRect rc = NSMakeRect(
                0., self.bounds.size.height - m_NonOverlappedHeight, self.bounds.size.width, m_NonOverlappedHeight);
            m_TrackingArea = [[NSTrackingArea alloc] initWithRect:rc options:tracking_flags owner:self userInfo:nil];
            [self addTrackingArea:m_TrackingArea];
        }
    }
    else {
        if( m_TrackingArea == nil ) {
            const NSTrackingAreaOptions tracking_flags =
                NSTrackingActiveInKeyWindow | NSTrackingCursorUpdate | NSTrackingInVisibleRect;
            m_TrackingArea = [[NSTrackingArea alloc] initWithRect:NSRect {}
                                                          options:tracking_flags
                                                            owner:self
                                                         userInfo:nil];
            [self addTrackingArea:m_TrackingArea];
        }
    }
}

@end

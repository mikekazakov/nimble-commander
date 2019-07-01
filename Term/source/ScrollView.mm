// Copyright (C) 2015-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FontCache.h>
#include "Parser.h"
#include "View.h"
#include "Screen.h"
#include "Settings.h"
#include "ScrollView.h"
#include "FlippableHolder.h"

using namespace nc;
using namespace nc::term;

static const NSEdgeInsets g_Insets = { 2., 5., 2., 5. };

@implementation NCTermScrollView
{
    NCTermView                     *m_View;
    NCTermFlippableHolder          *m_ViewHolder;
    std::unique_ptr<term::Screen>   m_Screen;
    std::shared_ptr<nc::term::Settings>m_Settings;
    int                             m_SettingsNotificationTicket;
    bool                            m_MouseInsideNonOverlappedArea;
}

@synthesize view = m_View;

- (id)initWithFrame:(NSRect)frameRect
        attachToTop:(bool)top
           settings:(std::shared_ptr<nc::term::Settings>)settings
{
    assert(settings);
    self = [super initWithFrame:frameRect];
    if(self) {
        m_MouseInsideNonOverlappedArea = false;
        self.customCursor = NSCursor.IBeamCursor;
        
        auto rc = self.contentView.bounds;
        m_Settings = settings;
        m_View = [[NCTermView alloc] initWithFrame:rc];
        m_View.settings = settings;
        m_ViewHolder = [[NCTermFlippableHolder alloc] initWithFrame:rc
                                                            andView:m_View
                                                          beFlipped:top];
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
        self.verticalLineScroll = m_View.fontCache.Height();
        
        m_Screen = std::make_unique<term::Screen>(floor(rc.size.width / m_View.fontCache.Width()),
                                                  floor(rc.size.height / m_View.fontCache.Height()));
        
        [m_View AttachToScreen:m_Screen.get()];
        
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[m_ViewHolder(>=100)]-0-|"
                                                 options:0
                                                 metrics:nil
                                                   views:NSDictionaryOfVariableBindings(m_ViewHolder)]];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];
        
        __weak NCTermScrollView* weak_self = self;
        m_SettingsNotificationTicket = m_Settings->StartChangesObserving([weak_self]{
            if( auto strong_self = weak_self )
                [strong_self onSettingsChanged];
        });
        
        const auto tracking_flags =
            NSTrackingActiveInKeyWindow |
            NSTrackingMouseMoved |
            NSTrackingMouseEnteredAndExited |
            NSTrackingInVisibleRect;
        const auto tracking = [[NSTrackingArea alloc] initWithRect:NSRect()
                                                           options:tracking_flags                          
                                                             owner:self
                                                          userInfo:nil];
        [self addTrackingArea:tracking];         
    }
    return self;
}

- (id)initWithFrame:(NSRect)frameRect attachToTop:(bool)top
{
    return [self initWithFrame:frameRect
                   attachToTop:top
                   settings:DefaultSettings::SharedDefaultSettings()];
}

- (void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void) mouseMoved:(NSEvent *)event
{    
    const auto hit_view = [self.window.contentView hitTest:event.locationInWindow];
    const auto inside = (bool)[hit_view isDescendantOf:self]; 
    if( inside ) {        
        if( m_MouseInsideNonOverlappedArea == false ) {
            m_MouseInsideNonOverlappedArea = true;
            [self mouseEnteredNonOverlappedArea];
        }
    }
    else {
        if( m_MouseInsideNonOverlappedArea == true ) {
            m_MouseInsideNonOverlappedArea = false;
            [self mouseExitedNonOverlappedArea];
        }
    }
}

- (void) mouseEntered:(NSEvent *)event
{
    [self mouseMoved:event];
}

- (void) mouseExited:(NSEvent *)[[maybe_unused]]_event
{
    if( m_MouseInsideNonOverlappedArea == true ) {
        m_MouseInsideNonOverlappedArea = false;
        [self mouseExitedNonOverlappedArea];
    }
}

- (void)cursorUpdate:(NSEvent *)[[maybe_unused]]_event
{
}

- (void) mouseEnteredNonOverlappedArea
{
    [self.customCursor push];    
}

- (void) mouseExitedNonOverlappedArea
{
    [self.customCursor pop];
}

- (void)viewDidMoveToWindow
{
    if( self.window == nil && m_MouseInsideNonOverlappedArea ) {
        m_MouseInsideNonOverlappedArea = false;
        [self mouseExitedNonOverlappedArea];
    }
}

- (term::Screen&) screen
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
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
}

- (void)frameDidChange
{
    if( m_Screen == nullptr )
        return;
    
    const auto full_size = self.contentView.frame.size;     
    
    int sy = floor(full_size.height / m_View.fontCache.Height());
    int sx = floor(full_size.width / m_View.fontCache.Width());

    if(sx != m_Screen->Width() || sy != m_Screen->Height()) {
        auto lock = m_Screen->AcquireLock();
        m_Screen->ResizeScreen(sx, sy);
        if( auto p = m_View.parser )
            p->Resized();
    }
    [self tile];
    [m_View adjustSizes:true];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    // is this code necessary?
    NSRect scrollRect;
    scrollRect = [self documentVisibleRect];
    scrollRect.origin.y +=  floor(theEvent.deltaY) *
                            self.verticalLineScroll *
                            (m_ViewHolder.isFlipped ? -1 : 1);
    [(NSView *)self.documentView scrollRectToVisible:scrollRect];
}

- (void) setScrollerStyle:(NSScrollerStyle)scrollerStyle
{
    [super setScrollerStyle:scrollerStyle];
    [self frameDidChange];
}

- (void) tile
{
    [super tile];
    
    auto rc = self.contentView.frame;
    rc.origin.y += g_Insets.top;
    rc.origin.x += g_Insets.left;
    rc.size.height -= g_Insets.top + g_Insets.bottom;
    rc.size.width -= g_Insets.left + g_Insets.right;
    
    const auto rest = rc.size.height -
        floor(rc.size.height / m_View.fontCache.Height()) * m_View.fontCache.Height();
    rc.size.height -= rest;
    
    self.contentView.frame = rc;
}

- (NSEdgeInsets) viewInsets
{
    return g_Insets;
}

- (void) mouseDown:(NSEvent *)_event
{
    [m_View mouseDown:_event];
}

@end

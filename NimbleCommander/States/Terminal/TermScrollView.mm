//
//  TermScrollView.m
//  Files
//
//  Created by Michael G. Kazakov on 20/06/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include <Utility/FontCache.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include "TermParser.h"
#include "TermView.h"
#include "TermScreen.h"
#include "TermScrollView.h"

static const auto g_ConfigHideScrollbar = "terminal.hideVerticalScrollbar";

@interface TermScrollViewFlippableDocumentHolder : NSView
- (id)initWithFrame:(NSRect)frameRect andView:(TermView*)view beFlipped:(bool)flipped;
@end

@implementation TermScrollViewFlippableDocumentHolder
{
    bool m_Flipped;
}

- (id)initWithFrame:(NSRect)frameRect andView:(TermView*)view beFlipped:(bool)flipped
{
    self = [super initWithFrame:frameRect];
    if(self) {
        m_Flipped = flipped;

        view.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:view];
        
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[view]-0-|"
                                                 options:0
                                                 metrics:nil
                                                   views:NSDictionaryOfVariableBindings(view)]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[view]-0-|"
                                                 options:0
                                                 metrics:nil
                                                   views:NSDictionaryOfVariableBindings(view)]];
        self.translatesAutoresizingMaskIntoConstraints = false;
    }
    return self;
}

- (BOOL) isFlipped
{
    return m_Flipped;
}

- (NSRect)adjustScroll:(NSRect)proposedVisibleRect
{
    if( self.subviews.count > 0 &&
        [self.subviews[0] respondsToSelector:@selector(adjustScroll:)] )
        return [self.subviews[0] adjustScroll:proposedVisibleRect];
        
    return proposedVisibleRect;
}

@end

///////////////////////////////////////////////////////////////////////// TermScrollView

@implementation TermScrollView
{
    TermView                               *m_View;
    TermScrollViewFlippableDocumentHolder  *m_ViewHolder;
    unique_ptr<TermScreen>                  m_Screen;
    ThemesManager::ObservationTicket    m_ThemeObservation;        
}

@synthesize view = m_View;

- (id)initWithFrame:(NSRect)frameRect attachToTop:(bool)top
{
    self = [super initWithFrame:frameRect];
    if(self) {
        auto rc = self.contentView.bounds;
        
        m_View = [[TermView alloc] initWithFrame:rc];
        m_ViewHolder = [[TermScrollViewFlippableDocumentHolder alloc] initWithFrame:rc andView:m_View beFlipped:top];
        self.documentView = m_ViewHolder;
        self.hasVerticalScroller = !GlobalConfig().GetBool(g_ConfigHideScrollbar);
        self.borderType = NSNoBorder;
        self.verticalScrollElasticity = NSScrollElasticityNone;
        self.scrollsDynamically = true;
        self.contentView.copiesOnScroll = false;
        self.contentView.canDrawConcurrently = false;
        self.contentView.drawsBackground = true;
        self.contentView.backgroundColor = CurrentTheme().TerminalBackgroundColor();
        self.verticalLineScroll = m_View.fontCache.Height();
        
        m_Screen = make_unique<TermScreen>(floor(rc.size.width / m_View.fontCache.Width()),
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
        
        __weak TermScrollView* weak_self = self;
        m_ThemeObservation = AppDelegate.me.themesManager.ObserveChanges(
            ThemesManager::Notifications::Terminal, [weak_self]{
            if( auto strong_self = weak_self ) {
                [strong_self onFontChanged];
                strong_self.contentView.backgroundColor = CurrentTheme().TerminalBackgroundColor();
            }
        });
        
        
        [self frameDidChange];
        
    }
    return self;
}

- (void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (TermScreen&) screen
{
    assert(m_Screen);
    return *m_Screen;
}

- (void)onFontChanged
{
    [m_View reloadGeometry];
    [self frameDidChange]; // handle with care - it will cause geometry recalculating
}

- (void)frameDidChange
{
    const auto sz = [TermView insetSize:NSMakeSize(m_View.frame.size.width, self.contentView.frame.size.height)];
    
    int sy = floor(sz.height / m_View.fontCache.Height());
    int sx = floor(sz.width / m_View.fontCache.Width());

    if(sx != m_Screen->Width() || sy != m_Screen->Height()) {
        auto lock = m_Screen->AcquireLock();
        m_Screen->ResizeScreen(sx, sy);
        if( auto p = m_View.parser )
            p->Resized();
    }
    [m_View adjustSizes:true];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    // is this code necessary?
    NSRect scrollRect;
    scrollRect = [self documentVisibleRect];
//    cout << theEvent.deltaY << endl;
    scrollRect.origin.y +=  floor(theEvent.deltaY) *
                            self.verticalLineScroll *
//                            m_View.fontCache.Height() *
                            (m_ViewHolder.isFlipped ? -1 : 1);
    [(NSView *)self.documentView scrollRectToVisible:scrollRect];
}

- (void) setScrollerStyle:(NSScrollerStyle)scrollerStyle
{
    [super setScrollerStyle:scrollerStyle];
    [self frameDidChange];
}

@end

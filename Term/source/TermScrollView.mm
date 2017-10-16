//
//  TermScrollView.m
//  Files
//
//  Created by Michael G. Kazakov on 20/06/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include <Utility/FontCache.h>
#include "Parser.h"
#include "TermView.h"
#include "Screen.h"
#include "Settings.h"
#include "TermScrollView.h"

using namespace nc;
using namespace nc::term;

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
    unique_ptr<term::Screen>                  m_Screen;
    
    shared_ptr<nc::term::Settings> m_Settings;
    int m_SettingsNotificationTicket;
}

@synthesize view = m_View;

- (id)initWithFrame:(NSRect)frameRect
        attachToTop:(bool)top
        settings:(shared_ptr<nc::term::Settings>)settings
{
    assert(settings);
    self = [super initWithFrame:frameRect];
    if(self) {
        auto rc = self.contentView.bounds;
        m_Settings = settings;
        m_View = [[TermView alloc] initWithFrame:rc];
        m_View.settings = settings;
        m_ViewHolder = [[TermScrollViewFlippableDocumentHolder alloc] initWithFrame:rc andView:m_View beFlipped:top];
        self.documentView = m_ViewHolder;
        self.hasVerticalScroller = !settings->HideScrollbar();
        self.borderType = NSNoBorder;
        self.verticalScrollElasticity = NSScrollElasticityNone;
        self.scrollsDynamically = true;
        self.contentView.copiesOnScroll = false;
        self.contentView.canDrawConcurrently = false;
        self.contentView.drawsBackground = true;
        self.contentView.backgroundColor = m_Settings->BackgroundColor();
        self.verticalLineScroll = m_View.fontCache.Height();
        
        m_Screen = make_unique<term::Screen>(floor(rc.size.width / m_View.fontCache.Width()),
                                             floor(rc.size.height / m_View.fontCache.Height()));
        
        [m_View AttachToScreen:m_Screen.get()];
        
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[m_ViewHolder(>=100)]-0-|"
                                                 options:0
                                                 metrics:nil
                                                   views:NSDictionaryOfVariableBindings(m_ViewHolder)]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:top ? @"V:|-0-[m_ViewHolder]" :
                                                               @"V:[m_ViewHolder]-0-|"
                                                 options:0
                                                 metrics:nil
                                                   views:NSDictionaryOfVariableBindings(m_ViewHolder)]];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];
        
        __weak TermScrollView* weak_self = self;
        m_SettingsNotificationTicket = m_Settings->StartChangesObserving([weak_self]{
            if( auto strong_self = weak_self )
                [strong_self onSettingsChanged];
        });
        
        [self frameDidChange];
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

- (term::Screen&) screen
{
    assert(m_Screen);
    return *m_Screen;
}

- (void)onSettingsChanged
{
    self.contentView.backgroundColor = m_Settings->BackgroundColor();
    if( m_View.font != m_Settings->Font() ) {
        m_View.font = m_Settings->Font();
        [self frameDidChange]; // handle with care - it will cause geometry recalculating
    }
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

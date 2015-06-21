//
//  TermScrollView.m
//  Files
//
//  Created by Michael G. Kazakov on 20/06/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "TermScrollView.h"
#import "FontCache.h"
#import "TermParser.h"
#import "Common.h"

@implementation TermScrollView
{
    TermView               *m_View;
    unique_ptr<TermScreen>  m_Screen;
    
    
}

@synthesize view = m_View;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self) {
        auto rc = self.contentView.bounds;
        
//        m_View = [[TermView alloc] initWithFrame:self.frame];
        m_View = [[TermView alloc] initWithFrame:rc];
        self.documentView = m_View;
        self.hasVerticalScroller = true;
        self.borderType = NSNoBorder;
        self.verticalScrollElasticity = NSScrollElasticityNone;
        self.scrollsDynamically = true;
        self.contentView.copiesOnScroll = false;
        self.contentView.canDrawConcurrently = false;
        self.contentView.drawsBackground = false;
        
        m_Screen = make_unique<TermScreen>(floor(rc.size.width / m_View.fontCache.Width()),
                                           floor(rc.size.height / m_View.fontCache.Height()));
        
        [m_View AttachToScreen:m_Screen.get()];
        
        m_View.translatesAutoresizingMaskIntoConstraints = NO;
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[m_View(>=100)]-0-|"
                                                 options:0
                                                 metrics:nil
                                                   views:NSDictionaryOfVariableBindings(m_View)]];
        [self addConstraint:
         [NSLayoutConstraint constraintWithItem:m_View
                                      attribute:NSLayoutAttributeHeight
                                      relatedBy:NSLayoutRelationGreaterThanOrEqual
                                         toItem:self.contentView
                                      attribute:NSLayoutAttributeHeight
                                     multiplier:1
                                       constant:0]];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];
        
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

- (void)frameDidChange
{
    int sy = floor(self.contentView.frame.size.height / m_View.fontCache.Height());
    int sx = floor(m_View.frame.size.width / m_View.fontCache.Width());

    if(sx != m_Screen->Width() || sy != m_Screen->Height()) {
        m_Screen->ResizeScreen(sx, sy);
        if( auto p = m_View.parser )
            p->Resized();
    }
    [m_View adjustSizes:true];
}


@end

//
//  StackOfDisappearingWidgets.m
//  Files
//
//  Created by Michael G. Kazakov on 12.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <assert.h>
#include <vector>
#include <deque>
#import "StackOfDisappearingWidgets.h"

static const double g_Gap = 8.0;

@implementation StackOfDisappearingWidgets
{
    StackOfDisappearingWidgetsOrientation m_Orientation;
    std::vector<NSView*>                  m_Widgets;
    NSMutableArray                        *m_Constraints;
    NSView                                *m_AnchorView;
    NSView                                *m_SuperView;
    bool                                  m_AllObjectsAdded;
    std::deque<NSView*>                   m_Deque;
}

- (id)initWithOrientation:(StackOfDisappearingWidgetsOrientation) _orientation AnchorView:(NSView*) _view SuperView:(NSView*)_sview
{
    self = [super init];
    if(self)
    {
        m_Orientation = _orientation;
        m_AnchorView = _view;
        m_SuperView = _sview;
        m_AllObjectsAdded = false;
        m_Constraints = [NSMutableArray new];
    }
    return self;
}
- (void) dealloc
{
    for(NSView *v: m_Widgets)
        [v removeObserver:self forKeyPath:@"hidden"];
}

- (void) AddWidget:(NSView*)_widget
{
    assert(!m_AllObjectsAdded);
    m_Widgets.push_back(_widget);
}

- (void) Done
{
    m_AllObjectsAdded = true;
 
    for(NSView *v: m_Widgets)
        [v addObserver:self forKeyPath:@"hidden" options:0 context:0];

    [self BuildLayout];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self BuildLayout];
}

- (void) BuildLayout
{
    assert(m_AllObjectsAdded);    
    int last_visible = 0;
    for(NSView *v: m_Widgets)
        if([v isHidden])
            m_Deque.push_back(v);
        else
            m_Deque.insert(m_Deque.begin() + last_visible++, v);
    
    [m_SuperView removeConstraints:m_Constraints];
    [m_Constraints removeAllObjects];
    
    NSView *last = m_AnchorView;
    for(NSView *v: m_Deque)
    {
        if(m_Orientation == StackOfDisappearingWidgetsOrientation::LeftToRight)
            [m_Constraints addObject:[NSLayoutConstraint constraintWithItem:v
                                                                  attribute:NSLayoutAttributeLeft
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:last
                                                                  attribute:NSLayoutAttributeRight
                                                                 multiplier:1
                                                                   constant:g_Gap]];
        else if(m_Orientation == StackOfDisappearingWidgetsOrientation::RightToLeft)
             [m_Constraints addObject:[NSLayoutConstraint constraintWithItem:v
                                                                   attribute:NSLayoutAttributeRight
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:last
                                                                   attribute:NSLayoutAttributeLeft
                                                                  multiplier:1
                                                                    constant:-g_Gap]];
        
        [m_Constraints addObject:[NSLayoutConstraint constraintWithItem:v
                                                              attribute:NSLayoutAttributeCenterY
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:m_AnchorView
                                                              attribute:NSLayoutAttributeCenterY
                                                             multiplier:1
                                                               constant:0]];
        
        last = v;
    }
    
    [m_SuperView addConstraints:m_Constraints];
    
    m_Deque.clear();    
}

@end

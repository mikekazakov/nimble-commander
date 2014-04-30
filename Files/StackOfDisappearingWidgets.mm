//
//  StackOfDisappearingWidgets.m
//  Files
//
//  Created by Michael G. Kazakov on 12.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "StackOfDisappearingWidgets.h"
#import "Common.h"

static const double g_Gap = 8.0;

@implementation StackOfDisappearingWidgets
{
    StackOfDisappearingWidgetsOrientation m_Orientation;
    vector<NSView*>                  m_Widgets;
    NSMutableArray                        *m_Constraints;
    NSView                                *m_AnchorView;
    NSView                                *m_SuperView;
    bool                                  m_AllObjectsAdded;
    dispatch_queue_t                      m_WorkQueue;
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
        m_WorkQueue = dispatch_queue_create("info.filesmanager.StackOfDisappearingWidgets", 0);
    }
    return self;
}

- (void) dealloc
{
    for(NSView *v: m_Widgets)
        [v removeObserver:self forKeyPath:@"hidden"];
    dispatch_release(m_WorkQueue);
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
    dispatch_async(m_WorkQueue, ^{
        [self BuildLayout];
    });
}

- (void) BuildLayout
{
    assert(m_AllObjectsAdded);
    vector<__weak NSView*> visible;
    vector<__weak NSView*> hidden;
    
    for(NSView *v: m_Widgets)
        if([v isHidden])
            hidden.push_back(v);
        else
            visible.push_back(v);
    
    NSMutableArray *to_add = [NSMutableArray arrayWithCapacity:m_Widgets.size()*2];
    
    NSView *last = m_AnchorView;
    for(NSView *v: visible)
    {
        if(m_Orientation == StackOfDisappearingWidgetsOrientation::LeftToRight)
            [to_add addObject:[NSLayoutConstraint constraintWithItem:v
                                                                  attribute:NSLayoutAttributeLeft
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:last
                                                                  attribute:NSLayoutAttributeRight
                                                                 multiplier:1
                                                                   constant:g_Gap]];
        else if(m_Orientation == StackOfDisappearingWidgetsOrientation::RightToLeft)
             [to_add addObject:[NSLayoutConstraint constraintWithItem:v
                                                                   attribute:NSLayoutAttributeRight
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:last
                                                                   attribute:NSLayoutAttributeLeft
                                                                  multiplier:1
                                                                    constant:-g_Gap]];
        
        [to_add addObject:[NSLayoutConstraint constraintWithItem:v
                                                              attribute:NSLayoutAttributeCenterY
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:m_AnchorView
                                                              attribute:NSLayoutAttributeCenterY
                                                             multiplier:1
                                                               constant:0]];

        last = v;
    }
    
    for(NSView *v: hidden)
    {
        [to_add addObject:[NSLayoutConstraint constraintWithItem:v
                                                              attribute:NSLayoutAttributeLeft
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:m_SuperView
                                                              attribute:NSLayoutAttributeLeft
                                                             multiplier:1
                                                               constant:-10000]];
        [to_add addObject:[NSLayoutConstraint constraintWithItem:v
                                                              attribute:NSLayoutAttributeTop
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:m_SuperView
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1
                                                               constant:-10000]];
    }
    
    NSMutableArray *to_remove = [NSMutableArray new];
    [to_remove addObjectsFromArray:m_Constraints];
    
    for(int i = 0; i < [to_add count]; ++i)
    {
        NSLayoutConstraint *c_new = [to_add objectAtIndex:i];
        for(NSLayoutConstraint *c_old: to_remove)
            if(c_new.firstItem == c_old.firstItem &&
               c_new.firstAttribute == c_old.firstAttribute &&
               c_new.secondItem == c_old.secondItem &&
               c_new.secondAttribute == c_old.secondAttribute &&
               c_new.constant == c_old.constant
                )
            {
                [to_remove removeObject:c_old];
                [to_add removeObject:c_new];
                --i;
                break;
            }
    }
    
    for(NSLayoutConstraint *c: to_remove)
        [m_Constraints removeObject: c];
    for(NSLayoutConstraint *c: to_add)
        [m_Constraints addObject: c];
    
    if(!dispatch_is_main_queue())
        dispatch_sync(dispatch_get_main_queue(), ^{
            [m_SuperView removeConstraints:to_remove];
            [m_SuperView addConstraints:to_add];
        });
    else
    {
        [m_SuperView removeConstraints:to_remove];
        [m_SuperView addConstraints:to_add];
    }    
}

@end

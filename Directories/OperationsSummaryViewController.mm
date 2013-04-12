//
//  OperationsSummaryViewController.m
//  Directories
//
//  Created by Pavel Dogurevich on 23.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "OperationsSummaryViewController.h"

#import "GenericOperationView.h"
#import "OperationsController.h"

// "Private" methods.
@interface OperationsSummaryViewController ()

- (void)InitView;

- (void)ShowList;
- (void)HideList;

- (void)observeValueForKeyPath:(NSString *)_keypath ofObject:(id)_object
                        change:(NSDictionary *)_change context:(void *)_context;

@end


@implementation OperationsSummaryViewController
{
    OperationsController *m_OperationsController;
    
    // Original frame of the operations list.
    NSRect m_ListFrame;
    // Original superview of the operation list.
    NSView *m_ListSuperview;
    
    BOOL m_ListVisible;
}
@synthesize OperationsController = m_OperationsController;

- (void)dealloc
{
    [m_OperationsController removeObserver:self forKeyPath:@"OperationsCount"];
}

- (void)InitView
{    
    m_ListFrame = self.ScrollView.frame;
    m_ListSuperview = self.ScrollView.superview;
}

- (void)ShowList
{
    assert(!m_ListVisible);
    
    const NSUInteger max_height_in_items = 5;
    
    // Set opaque background.
//    NSArray *colors = [NSArray arrayWithObjects:
//                       [NSColor colorWithDeviceRed:0.9 green:0.9 blue:0.9 alpha:1.0],
//                       [NSColor colorWithDeviceRed:0.86 green:0.86 blue:0.86 alpha:1.0],
//                       nil];
//    [self.CollectionView setBackgroundColors:colors];
    
    // Calculate height of the expanded list.
    NSUInteger item_height = self.CollectionView.itemPrototype.view.frame.size.height;
    NSUInteger count = self.OperationsController.OperationsCount;
    NSUInteger window_height_in_items = self.view.window.frame.size.height / item_height;
    NSUInteger height_in_items = max_height_in_items;
    if (height_in_items > count) height_in_items = count;
    if (height_in_items > window_height_in_items) height_in_items = window_height_in_items;
    
    CGFloat width = self.view.frame.size.width;
    CGFloat height = height_in_items * item_height;
    
    CGPoint origin = [self.view convertPoint:NSMakePoint(45, 0)
                                      toView:self.view.window.contentView];
    origin.y -= height - self.view.frame.size.height;
    [self.view.window.contentView addSubview:self.ScrollView];
    [self.ScrollView setFrameOrigin:origin];
    
    // Apply new height.
    [self.ScrollView setFrameSize:NSMakeSize(width, height)];
    
    m_ListVisible = YES;
}

- (void)HideList
{
    assert(m_ListVisible);
    
    [_ScrollView removeFromSuperview];
    m_ListVisible = NO;
}

- (void)observeValueForKeyPath:(NSString *)_keypath ofObject:(id)_object
                        change:(NSDictionary *)_change context:(void *)_context
{
    if (_object == m_OperationsController && [_keypath isEqualToString:@"OperationsCount"])
    {
        // Count of operations is chaged. Update current operation.
        if (m_OperationsController.Operations.count == 0)
            self.CurrentOperation = nil;
        else
        {
            Operation *first_op = m_OperationsController.Operations[0];
            if (self.CurrentOperation != first_op)
                self.CurrentOperation = first_op;
        }
        
        return;
    }
    
    [super observeValueForKeyPath:_keypath ofObject:_object
                           change:_change context:_context];
}

- (IBAction)ShowOpListButtonAction:(NSButton *)sender
{
    if (m_ListVisible)
        [self HideList];
    else
    {
        // Expand list only if there is more than 1 operation.
        if (m_OperationsController.OperationsCount > 1)
            [self ShowList];
    }
}

- (id)initWthController:(OperationsController *)_controller
{
    self = [super initWithNibName:@"OperationsSummaryViewController" bundle:nil];
    if (self)
    {
        m_OperationsController = _controller;
        m_ListVisible = NO;
        [m_OperationsController addObserver:self
                                 forKeyPath:@"OperationsCount"
                                    options:NSKeyValueObservingOptionNew
                                    context:nil];
        
        [self loadView];
        [self InitView];
    }
    
    return self;
}

- (void)AddViewTo:(NSView *)_parent
{
    [_parent addSubview:self.view];
}

@end

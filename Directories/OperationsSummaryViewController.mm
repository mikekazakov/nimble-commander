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
    
    BOOL m_ListVisible;
}
@synthesize OperationsController = m_OperationsController;

- (void)dealloc
{
    [m_OperationsController removeObserver:self forKeyPath:@"OperationsCount"];
}

- (void)InitView
{
    NSArray *colors = [NSArray arrayWithObjects:
                       [NSColor colorWithDeviceRed:0.9 green:0.9 blue:0.9 alpha:1.0],
                       [NSColor colorWithDeviceRed:0.86 green:0.86 blue:0.86 alpha:1.0],
                       nil];
    [_CollectionView setBackgroundColors:colors];
    
    _ScrollView.layer.cornerRadius = 3;
    _ScrollView.layer.borderWidth = 1;
    _ScrollView.layer.borderColor = CGColorCreateGenericRGB(0.5, 0.5, 0.5, 1);
    
    [_ScrollView setHidden:YES];
}

- (void)ShowList
{    
    const NSUInteger max_height_in_items = 5;
    const int x_delta = 47, y_delta = -3;
    
    // Calculate height of the expanded list.
    NSUInteger item_height = self.CollectionView.itemPrototype.view.frame.size.height;
    NSUInteger count = self.OperationsController.OperationsCount;
    NSUInteger window_height_in_items = self.view.window.frame.size.height / item_height;
    NSUInteger height_in_items = max_height_in_items;
    if (height_in_items > count) height_in_items = count;
    if (height_in_items > window_height_in_items) height_in_items = window_height_in_items;
    
    CGFloat width = _ScrollView.frame.size.width;
    CGFloat height = height_in_items * item_height + 2;
    
    CGPoint origin = [self.view convertPoint:NSMakePoint(x_delta, y_delta)
                                      toView:self.view.window.contentView];
    origin.y -= height - self.view.frame.size.height;
    //[self.view.window.contentView addSubview:self.ScrollView];
    [self.ScrollView setFrameOrigin:origin];
    
    // Apply new height.
    [self.ScrollView setFrameSize:NSMakeSize(width, height)];
    
    [self.ScrollView setHidden:NO];
    m_ListVisible = YES;
}

- (void)HideList
{    
    [_ScrollView setHidden:YES];
    m_ListVisible = NO;
}

- (void)observeValueForKeyPath:(NSString *)_keypath ofObject:(id)_object
                        change:(NSDictionary *)_change context:(void *)_context
{
    if (_object == m_OperationsController && [_keypath isEqualToString:@"OperationsCount"])
    {
        // Count of operations is chaged. Update current operation.
        if (m_OperationsController.Operations.count == 0)
        {
            self.CurrentOperation = nil;
            if (m_ListVisible)
                [self HideList];
        }
        else
        {
            Operation *first_op = m_OperationsController.Operations[0];
            if (self.CurrentOperation != first_op)
                self.CurrentOperation = first_op;
            
            // TODO: refactor
            const NSUInteger max_height_in_items = 5;
            if (m_ListVisible && m_OperationsController.Operations.count < max_height_in_items)
                [self ShowList];
            
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
    else if (m_OperationsController.OperationsCount > 0)
    {
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
    [_parent.window.contentView addSubview:self.ScrollView];
}

@end

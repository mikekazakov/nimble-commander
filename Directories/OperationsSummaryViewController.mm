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

- (void)ExpandList;
- (void)ShrinkList;

@end


@implementation OperationsSummaryViewController
{
    OperationsController *m_OperationsController;
    
    // Original frame of the operations list.
    NSRect m_ListFrame;
    // Original superview of the operation list.
    NSView *m_ListSuperview;
    
    BOOL m_Expanded;
}
@synthesize OperationsController = m_OperationsController;

- (void)InitView
{
    self.OperationsCountLabel.stringValue = @"0";
    self.DialogsCountLabel.stringValue = @"0";
    
    m_ListFrame = self.ScrollView.frame;
    m_ListSuperview = self.ScrollView.superview;
}

- (void)ExpandList
{
    const NSUInteger max_height_in_items = 5;
    
    // Make list show oll operations.
    [self.OperationsArrayController setFilterPredicate:nil];
    
    // Set opaque background.
    NSArray *colors = [NSArray arrayWithObjects:
                       [NSColor colorWithDeviceRed:0.9 green:0.9 blue:0.9 alpha:1.0],
                       [NSColor colorWithDeviceRed:0.86 green:0.86 blue:0.86 alpha:1.0],
                       nil];
    [self.CollectionView setBackgroundColors:colors];
    
    // Calculate height of the expanded list.
    NSUInteger item_height = self.CollectionView.itemPrototype.view.frame.size.height;
    NSUInteger count = self.OperationsController.OperationsCount;
    NSUInteger window_height_in_items = self.view.window.frame.size.height / item_height;
    NSUInteger height_in_items = max_height_in_items;
    if (height_in_items > count) height_in_items = count;
    if (height_in_items > window_height_in_items) height_in_items = window_height_in_items;
    
    CGFloat width = self.ScrollView.frame.size.width;
    CGFloat height = height_in_items * item_height;
    
    // Move list to window.
    if (self.ScrollView.superview != self.view.window.contentView)
    {
        CGPoint origin = [self.ScrollView convertPoint:NSMakePoint(0, 0)
                                                toView:self.view.window.contentView];
        origin.y -= height;
        [self.ScrollView removeFromSuperviewWithoutNeedingDisplay];
        [self.view.window.contentView addSubview:self.ScrollView];
        [self.ScrollView setFrameOrigin:origin];
    }
    
    // Apply new height.
    [self.ScrollView setFrameSize:NSMakeSize(width, height)];
    
    m_Expanded = true;
}

- (void)ShrinkList
{
    // Make list show only the first operation.
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(Operation *_obj, NSDictionary *)
    {
        return [self.OperationsController.Operations indexOfObject:_obj] == 0;
    }];
    
    [self.OperationsArrayController setFilterPredicate:predicate];
    
    // Set transparent background.
    NSArray *colors = [NSArray arrayWithObjects:[NSColor clearColor], nil];
    [self.CollectionView setBackgroundColors:colors];
    
    // Move list inside the summary view.
    if (self.ScrollView.superview != m_ListSuperview)
    {
        [self.ScrollView removeFromSuperviewWithoutNeedingDisplay];
        [m_ListSuperview addSubview:self.ScrollView];
        self.ScrollView.frame = m_ListFrame;
    }
    
    m_Expanded = false;
}

- (IBAction)ShowOpListButtonAction:(NSButton *)sender
{
    if (m_Expanded)
        [self ShrinkList];
    else
    {
        // Expand list only if there is more than 1 operation.
        if (m_OperationsController.OperationsCount > 1)
            [self ExpandList];
    }
}

- (id)initWthController:(OperationsController *)_controller
{
    self = [super initWithNibName:@"OperationsSummaryViewController" bundle:nil];
    if (self)
    {
        m_OperationsController = _controller;
        m_Expanded = NO;
        
        [self loadView];
        [self InitView];
        
        [self ShrinkList];
    }
    
    return self;
}

- (void)AddViewTo:(NSView *)_parent
{
    [_parent addSubview:self.view];
}

@end

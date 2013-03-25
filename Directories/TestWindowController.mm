//
//  TestWindowController.m
//  Directories
//
//  Created by Pavel Dogurevich on 24.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "TestWindowController.h"

#import "OperationsSummaryViewController.h"
#import "TimedDummyOperation.h"

@interface TestWindowController ()

@end

@implementation TestWindowController
{
    OperationsSummaryViewController *m_OpSummaryController;
    OperationsController *m_OperationsController;
}

- (id)init
{
    self = [super initWithWindowNibName:@"TestWindow"];
    if (self) {
        // Initialization code here.
        m_OperationsController = [[OperationsController alloc] init];
        m_OpSummaryController = [[OperationsSummaryViewController alloc] initWthController:m_OperationsController];
}
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [m_OpSummaryController AddViewTo:self.TempView];
}

- (IBAction)AddOperationButtonAction:(NSButton*)sender
{
    int time = rand()%7;
    TimedDummyOperation *op = [[TimedDummyOperation alloc] initWithTime:time];
    [m_OperationsController AddOperation:op];
}

@end

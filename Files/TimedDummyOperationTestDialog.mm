//
//  TimedDummyOperationTestDialog.m
//  Directories
//
//  Created by Pavel Dogurevich on 30.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "TimedDummyOperationTestDialog.h"

@interface TimedDummyOperationTestDialog ()

@end

@implementation TimedDummyOperationTestDialog
{
    int m_Time;
}

- (id)init
{
    self = [super initWithWindowNibName:@"TimedDummyOperationTestDialog"];
    if (self) {
        // Initialization code here.
        self.NewTime = -1;
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    NSString *str = [NSString stringWithFormat:@"Current operation time: %i ms", m_Time];
    [self.Label setStringValue:str];
}

- (IBAction)OkButtonAction:(NSButton *)sender
{
    [self CloseDialogWithResult:OperationDialogResult::Continue];
}

- (IBAction)CancelButtonAction:(NSButton *)sender
{
    [self CloseDialogWithResult:OperationDialogResult::Stop];
}

- (IBAction)PostponeButtonAction:(NSButton *)sender
{
    [self HideDialog];
}

- (IBAction)SetTimeButtonAction:(NSButton *)sender
{
    self.NewTime = [self.TimeField intValue];
    [self CloseDialogWithResult:OperationDialogResult::Continue];
}

- (void)SetTime:(int)_optime
{
    m_Time = _optime;
}

@end

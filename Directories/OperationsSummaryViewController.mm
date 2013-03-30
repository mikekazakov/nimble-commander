//
//  OperationsSummaryViewController.m
//  Directories
//
//  Created by Pavel Dogurevich on 23.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "OperationsSummaryViewController.h"

@implementation OperationsSummaryViewController
{
    OperationsController *m_OperationsController;
    NSTimer* m_UpdateTimer;
}

- (void)ToggleTopOperationsControlsVisibility:(BOOL)_visible
{
    [[self.TopOperationProgress animator] setAlphaValue:(_visible ? 1.0f : 0.0f)];
    [[self.TopOperationCaption animator] setAlphaValue:(_visible ? 1.0f : 0.0f)];
}

- (void)InitView
{
    self.OperationsCountButton.alphaValue = 0.0f;
    [self.OperationsCountButton setEnabled:NO];
    
    self.TopOperationProgress.alphaValue = 0.0f;
    
    self.TopOperationCaption.alphaValue = 0.0f;
    
    self.DialogButton.alphaValue = 0.0f;
    [self.DialogButton setEnabled:NO];
}

- (void)UpdateView
{
    // Update operations count button.
    NSUInteger count = [m_OperationsController GetOperationsCount];
    if (count <= 1)
    {
        if ([self.OperationsCountButton isEnabled])
        {
            // Need to disable and hide button.
            [[self.OperationsCountButton animator] setAlphaValue:0.0f];
            [self.OperationsCountButton setEnabled:NO];
        }
    }
    else
    {
        if (![self.OperationsCountButton isEnabled])
        {
            // Need to enable and show button.
            [[self.OperationsCountButton animator] setAlphaValue:1.0f];
            [self.OperationsCountButton setEnabled:YES];
        }
        
        // Just change button title.
        self.OperationsCountButton.title = [@(count) stringValue];
    }
    
    // Update top operation view.
    Operation *op = [m_OperationsController GetOperation:0];
    
    if (op == nil && self.TopOperation == nil)
    {
        // There is no top operation. Nothing to do.
    }
    else
    {
        if (op == nil)
        {
            // There is no top operation now.
            // Need to hide controls.
            [self ToggleTopOperationsControlsVisibility:NO];
        }
        else if (op != self.TopOperation && self.TopOperation == nil)
        {
            // There was no top operation and now there is a new one.
            // Need to show controls.
            [self ToggleTopOperationsControlsVisibility:YES];
        }
    
        self.TopOperation = op;
        
        if (self.TopOperation != nil)
        {
            // Update values.
            self.TopOperationCaption.stringValue = [self.TopOperation GetCaption];
            self.TopOperationProgress.doubleValue = 100*[self.TopOperation GetProgress];
        }
    }
    
    // Update top operation's dialog button.
    if ([self.TopOperation HasDialog])
    {
        if (![self.DialogButton isEnabled])
        {
            // Need to show button.
            [self.DialogButton setEnabled:YES];
            [self.DialogButton.animator setAlphaValue:1.0f];
        }
    }
    else
    {
        if ([self.DialogButton isEnabled])
        {
            // Need to hide button.
            [self.DialogButton setEnabled:NO];
            [self.DialogButton.animator setAlphaValue:0.0f];
        }
    }
}

- (id)initWthController:(OperationsController *)_controller
{
    self = [super initWithNibName:@"OperationsSummaryViewController" bundle:nil];
    if (self)
    {
        m_OperationsController = _controller;
        
        [self loadView];
        [self InitView];
        [self UpdateView];
        
        m_UpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.033
                                                         target:self
                                                       selector:@selector(UpdateView)
                                                       userInfo:nil
                                                        repeats:YES];
    }
    
    return self;
}

- (void)AddViewTo:(NSView *)_parent
{
    [_parent addSubview:self.view];
}

- (IBAction)OperationsCountButtonAction:(NSButton *)sender
{
    [[NSAlert alertWithMessageText:@"This is the list of operations :)" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""] runModal];
}

- (IBAction)PauseButtonAction:(NSButton *)sender
{
    if ([self.TopOperation IsPaused])
        [self.TopOperation Resume];
    else
        [self.TopOperation Pause];
}

- (IBAction)StopButtonAction:(NSButton *)sender
{
    [self.TopOperation Stop];
}

- (IBAction)DialogButtonAction:(NSButton *)sender
{
    assert(self.TopOperation);
    
    [self.TopOperation ShowDialogForWindow:[NSApp mainWindow]];
}

@end

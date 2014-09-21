//
//  ProcessSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 28.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "ProcessSheetController.h"
#import "Common.h"

static const auto g_ShowDelaySec = 0.15;

@implementation ProcessSheetController
{
    bool m_Running;
    bool m_UserCancelled;
    bool m_ClientClosed;
}

@synthesize userCancelled = m_UserCancelled;

- (id)init
{
    if(self = [super initWithWindowNibName:NSStringFromClass(self.class)])
    {
        m_Running = false;
        m_UserCancelled = false;
        m_ClientClosed = false;
    }
    return self;    
}

- (IBAction)OnCancel:(id)sender
{
    m_UserCancelled = true;
    if(self.OnCancelOperation)
        self.OnCancelOperation();

    [self Discard];
}

- (void)Show
{
    // consider using modal dialog here.
    
    if(m_Running == true)
        return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(g_ShowDelaySec * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if(m_ClientClosed)
            return;
        [self showWindow:self];
        m_Running = true;
    });
}

- (void)Close
{
    m_ClientClosed = true;
    [self Discard];
}

- (void) Discard
{
    if(m_Running == false)
        return;
    
    dispatch_to_main_queue(^{ [self.window close]; });
    m_Running = false;
}

@end

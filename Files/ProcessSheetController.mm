//
//  ProcessSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 28.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "ProcessSheetController.h"
#import "Common.h"

@implementation ProcessSheetController
{
    bool m_Running;
    bool m_UserCancelled;
    bool m_ClientClosed;
}

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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if(m_UserCancelled)
            return;
        [self showWindow:self];
        m_Running = true;
    });
}

- (void)Close
{
    m_UserCancelled = true;
    [self Discard];
}

- (void) Discard
{
    if(m_Running == false)
        return;
    
    if(dispatch_is_main_queue())
        [self.window close];
    else
        dispatch_to_main_queue(^{[self.window close];});
    m_Running = false;
}

- (bool) UserCancelled
{
    return m_UserCancelled;
}

@end

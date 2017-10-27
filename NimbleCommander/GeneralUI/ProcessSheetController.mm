// Copyright (C) 2014-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include "ProcessSheetController.h"

static const nanoseconds g_ShowDelay = 150ms;

@implementation ProcessSheetController
{
    bool m_Running;
    bool m_UserCancelled;
    bool m_ClientClosed;
}

@synthesize userCancelled = m_UserCancelled;

- (id)init
{
    // NEED EVEN MOAR GCD HACKS!!
    if(dispatch_is_main_queue()) {
        self = [super initWithWindowNibName:NSStringFromClass(self.class)];
        (void)self.window;
    }
    else {
        __block ProcessSheetController *me;
        dispatch_sync(dispatch_get_main_queue(), ^{
            me = [super initWithWindowNibName:NSStringFromClass(self.class)];
            (void)me.window;
        });
        self = me;
    }
    
    if(self) {
        self.window.movableByWindowBackground = true;
        m_Running = false;
        m_UserCancelled = false;
        m_ClientClosed = false;
    }
    return self;    
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
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
    dispatch_to_main_queue_after(g_ShowDelay,[=]{
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
    
    dispatch_to_main_queue([=]{ [self.window close]; });
    m_Running = false;
}

- (void) setTitle:(NSString *)title
{
    ((NSTextField*)[self.window.contentView viewWithTag:777]).stringValue = title;
}

- (NSString*) title
{
    return ((NSTextField*)[self.window.contentView viewWithTag:777]).stringValue;
}

@end

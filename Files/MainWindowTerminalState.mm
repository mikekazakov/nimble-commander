//
//  MainWindowTerminalState.m
//  Files
//
//  Created by Michael G. Kazakov on 26.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowTerminalState.h"
#import "TermShellTask.h"
#import "TermScreen.h"
#import "TermParser.h"
#import "TermView.h"
#import "MainWindowController.h"
#import "MessageBox.h"
#import "FontCache.h"
#import "ActionsShortcutsManager.h"
#import "TermScrollView.h"

#import "Common.h"
#import "common_paths.h"

@implementation MainWindowTerminalState
{
    TermScrollView             *m_TermScrollView;    
    unique_ptr<TermShellTask>    m_Task;
    unique_ptr<TermParser>  m_Parser;
    char            m_InitalWD[MAXPATHLEN];
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        strcpy(m_InitalWD, CommonPaths::Get(CommonPaths::Home).c_str());
        
        m_TermScrollView = [[TermScrollView alloc] initWithFrame:self.bounds];
        m_TermScrollView.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_TermScrollView];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_TermScrollView]-(==0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(m_TermScrollView)]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_TermScrollView]-(==0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(m_TermScrollView)]];

        
        m_Task.reset(new TermShellTask);
        auto task_ptr = m_Task.get();
        m_Parser = make_unique<TermParser>(m_TermScrollView.screen,
                                           [=](const void* _d, int _sz){
                                               task_ptr->WriteChildInput(_d, _sz);
                                           });
        m_Parser->SetTaskScreenResize([=](int sx, int sy) {
            task_ptr->ResizeWindow(sx, sy);
        });
        [m_TermScrollView.view AttachToParser:m_Parser.get()];
    }
    return self;
}

- (NSView*) windowContentView
{
    return self;
}

- (NSToolbar*) toolbar
{
    return nil;
}

- (void) SetInitialWD:(const char*)_wd
{
    if(_wd && strlen(_wd) > 0)
        strcpy(m_InitalWD, _wd);
}

- (void) Assigned
{
    // need right CWD here
    if(m_Task->State() == TermShellTask::StateInactive)
        m_Task->Launch(m_InitalWD, m_TermScrollView.screen.Width(), m_TermScrollView.screen.Height());
    
    __weak MainWindowTerminalState *weakself = self;
    
    m_Task->SetOnChildOutput(^(const void* _d, int _sz){
        if(MainWindowTerminalState *strongself = weakself) {
            bool newtitle = false;
            strongself->m_TermScrollView.screen.Lock();
            for(int i = 0; i < _sz; ++i) {
                int flags = 0;

                strongself->m_Parser->EatByte(((const char*)_d)[i], flags);

                if(flags & TermParser::Result_ChangedTitle)
                    newtitle = true;
            }
        
            strongself->m_Parser->Flush();
            strongself->m_TermScrollView.screen.Unlock();
        
            
            [strongself->m_TermScrollView.view.FPSDrawer invalidate];
            
            //            tmb.Reset("Parsed in: ");
            dispatch_to_main_queue( [=]{
                [strongself->m_TermScrollView.view adjustSizes:false];
                if(newtitle)
                    [strongself UpdateTitle];
            });
        }
    });
    
    m_Task->SetOnBashPrompt(^(const char *_cwd){
        if(MainWindowTerminalState *strongself = weakself) {
            strongself->m_TermScrollView.screen.SetTitle("");
            [strongself UpdateTitle];
        }
    });
    
    [self.window makeFirstResponder:m_TermScrollView.view];
    [self UpdateTitle];
}


- (void) UpdateTitle
{
    NSString *title = 0;
    
    m_TermScrollView.screen.Lock();
    if(strlen(m_TermScrollView.screen.Title()) > 0)
        title = [NSString stringWithUTF8String:m_TermScrollView.screen.Title()];
    m_TermScrollView.screen.Unlock();
    
    if(title == 0)
    {
        m_Task->Lock();
        string cwd = m_Task->CWD();
        m_Task->Unlock();
        
        if(!cwd.empty() && cwd.back() != '/')
            cwd += '/';
        title = [NSString stringWithUTF8String:cwd.c_str()];
    }

    dispatch_or_run_in_main_queue([=]{
        self.window.title = title;
    });
}

- (void) ChDir:(const char*)_new_dir
{
    m_Task->ChDir(_new_dir);
}

- (void) Execute:(const char *)_short_fn at:(const char*)_at
{
    m_Task->Execute(_short_fn, _at, nullptr);
}

- (void) Execute:(const char *)_short_fn at:(const char*)_at with_parameters:(const char*)_params
{
    m_Task->Execute(_short_fn, _at, _params);
}

- (void) Execute:(const char *)_full_fn with_parameters:(const char*)_params
{
    m_Task->ExecuteWithFullPath(_full_fn, _params);    
}

- (bool)WindowShouldClose:(MainWindowController*)sender
{
//    NSLog(@"1! %ld", CFGetRetainCount((__bridge CFTypeRef)self));
    
    if(m_Task->State() == TermShellTask::StateDead ||
       m_Task->State() == TermShellTask::StateInactive ||
       m_Task->State() == TermShellTask::StateShell)
        return true;
    
    auto children = m_Task->ChildrenList();
    if(children.empty())
        return true;

    MessageBox *dialog = [[MessageBox alloc] init];
    dialog.messageText = NSLocalizedString(@"Do you want to close this window?", "Asking to close window with processes running");
    NSMutableString *cap = [NSMutableString new];
    [cap appendString:NSLocalizedString(@"Closing this window will terminate the running processes: ", "Informing when closing with running terminal processes")];
    for(int i = 0; i < children.size(); ++i)
    {
        [cap appendString:[NSString stringWithUTF8String:children[i].c_str()]];
        if(i != children.size() - 1)
            [cap appendString:@", "];
    }
    [cap appendString:@"."];
    dialog.informativeText = cap;
    [dialog addButtonWithTitle:NSLocalizedString(@"Terminate And Close", "User confirmation on message box")];
    [dialog addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    [dialog beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSAlertFirstButtonReturn)
            [sender.window close];
    }];
    
    return false;
}

- (bool) isAnythingRunning
{
    auto state = m_Task->State();
    return state == TermShellTask::StateProgramExternal || state == TermShellTask::StateProgramInternal;
}

- (void) Terminate
{
    m_Task->Terminate();
}

- (string)CWD
{
    if(m_Task->State() == TermShellTask::StateInactive ||
       m_Task->State() == TermShellTask::StateDead)
        return "";
    
    return m_Task->CWD();
}

- (IBAction)OnShowTerminal:(id)sender
{
    [(MainWindowController*)self.window.delegate ResignAsWindowState:self];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto tag = item.tag;
    IF_MENU_TAG("menu.view.show_terminal") {
        item.title = NSLocalizedString(@"Hide Terminal", "Menu item title for hiding terminal");
        return true;
    }
    return true;
}

@end

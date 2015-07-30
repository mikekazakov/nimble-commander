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
#import "TermScrollView.h"
#import "MainWindowController.h"
#import "ActionsShortcutsManager.h"


#import "Common.h"
#import "common_paths.h"

@implementation MainWindowTerminalState
{
    TermScrollView             *m_TermScrollView;    
    unique_ptr<TermShellTask>   m_Task;
    unique_ptr<TermParser>      m_Parser;
    string                      m_InitalWD;
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        m_InitalWD = CommonPaths::Get(CommonPaths::Home);
        
        m_TermScrollView = [[TermScrollView alloc] initWithFrame:self.bounds attachToTop:true];
        m_TermScrollView.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_TermScrollView];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_TermScrollView]-(==0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(m_TermScrollView)]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_TermScrollView]-(==0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(m_TermScrollView)]];

        
        m_Task = make_unique<TermShellTask>();
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

- (void) SetInitialWD:(const string&)_wd
{
    if(!_wd.empty())
        m_InitalWD = _wd;
}

- (void) Assigned
{
    // need right CWD here
    if(m_Task->State() == TermShellTask::TaskState::Inactive)
        m_Task->Launch(m_InitalWD.c_str(), m_TermScrollView.screen.Width(), m_TermScrollView.screen.Height());
    
    __weak MainWindowTerminalState *weakself = self;
    
    m_Task->SetOnChildOutput([=](const void* _d, int _sz){
        if(MainWindowTerminalState *strongself = weakself) {


            
            bool newtitle = false;
            strongself->m_TermScrollView.screen.Lock();

            
//                        MachTimeBenchmark mtb;

            
            int flags = strongself->m_Parser->EatBytes((const unsigned char*)_d, _sz);
            
//                        auto nanos = mtb.Delta();
//                        static unsigned long nanos_total(0);
//                        nanos_total += nanos.count();
//                        static unsigned long bytes_total(0);
//                        bytes_total += _sz;
//                        auto nanos_pb = double(nanos_total) / double(bytes_total);
//                        printf( "parsing speed avg: %.0f\n", nanos_pb );
            
            
            
            
            if(flags & TermParser::Result_ChangedTitle)
                newtitle = true;
        
            strongself->m_TermScrollView.screen.Unlock();
            
            

            
            
            
            [strongself->m_TermScrollView.view.fpsDrawer invalidate];
            
//            mtb.ResetNano("Parsed in: ");
//            printf("(data size: %d)\n", _sz);

            
        
            dispatch_to_main_queue( [=]{
                [strongself->m_TermScrollView.view adjustSizes:false];
                if(newtitle)
                    [strongself UpdateTitle];
            });
        }
    });
    
    m_Task->SetOnBashPrompt([=](const char *_cwd, bool _changed){
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
    m_TermScrollView.screen.Lock();
    NSString *title = [NSString stringWithUTF8StdString:m_TermScrollView.screen.Title()];
    m_TermScrollView.screen.Unlock();
    
    if(title.length == 0) {
        string cwd = m_Task->CWD();        
        if(!cwd.empty() && cwd.back() != '/')
            cwd += '/';
        title = [NSString stringWithUTF8StdString:cwd];
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
    
    if(m_Task->State() == TermShellTask::TaskState::Dead ||
       m_Task->State() == TermShellTask::TaskState::Inactive ||
       m_Task->State() == TermShellTask::TaskState::Shell)
        return true;
    
    auto children = m_Task->ChildrenList();
    if(children.empty())
        return true;

    NSAlert *dialog = [[NSAlert alloc] init];
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
    [dialog beginSheetModalForWindow:sender.window completionHandler:^(NSModalResponse result) {
        if (result == NSAlertFirstButtonReturn)
            [sender.window close];
    }];
    
    return false;
}

- (bool) isAnythingRunning
{
    auto state = m_Task->State();
    return state == TermShellTask::TaskState::ProgramExternal || state == TermShellTask::TaskState::ProgramInternal;
}

- (void) Terminate
{
    m_Task->Terminate();
}

- (string)CWD
{
    if(m_Task->State() == TermShellTask::TaskState::Inactive ||
       m_Task->State() == TermShellTask::TaskState::Dead)
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

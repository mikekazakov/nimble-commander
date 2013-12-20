//
//  MainWindowTerminalState.m
//  Files
//
//  Created by Michael G. Kazakov on 26.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowTerminalState.h"
#import "TermTask.h"
#import "TermScreen.h"
#import "TermParser.h"
#import "TermView.h"
#import "MainWindowController.h"
#import "MessageBox.h"
#import "FontCache.h"

#import "Common.h"

@implementation MainWindowTerminalState
{
    TermTask        *m_Task;
    TermScreen      *m_Screen;
    TermParser      *m_Parser;
    TermView        *m_View;
    char            m_InitalWD[MAXPATHLEN];
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        strcpy(m_InitalWD, "/");
        GetUserHomeDirectoryPath(m_InitalWD);
        
        m_View = [[TermView alloc] initWithFrame:self.frame];
        [self setDocumentView:m_View];
        [self setHasVerticalScroller:YES];
        [self setBorderType:NSNoBorder];
        [self setVerticalScrollElasticity:NSScrollElasticityNone];
        [self setScrollsDynamically:YES];
        [[self contentView] setCopiesOnScroll:NO];
        [[self contentView] setCanDrawConcurrently:NO];
        [[self contentView] setDrawsBackground:NO];
        
        m_Task = new TermTask;
        m_Screen = new TermScreen(floor(frameRect.size.width / [m_View FontCache]->Width()),
                                  floor(frameRect.size.height / [m_View FontCache]->Height()));
        m_Parser = new TermParser(m_Screen, m_Task);
        [m_View AttachToScreen:m_Screen];
        [m_View AttachToParser:m_Parser];
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(frameDidChange)
                                                     name:NSViewFrameDidChangeNotification
                                                   object:self];
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    delete m_Parser;
    delete m_Screen;
    delete m_Task;
}

- (NSView*) ContentView
{
    return self;
}

- (void) SetInitialWD:(const char*)_wd
{
    if(_wd && strlen(_wd) > 0)
        strcpy(m_InitalWD, _wd);
}

- (void) Assigned
{
    // need right CWD here
    if(m_Task->State() == TermTask::StateInactive)
        m_Task->Launch(m_InitalWD, m_Screen->Width(), m_Screen->Height());
    
    __weak MainWindowTerminalState *weakself = self;
    
    m_Task->SetOnChildOutput(^(const void* _d, int _sz){
        //            MachTimeBenchmark tmb;
        if(weakself != nil)
        {
            __strong MainWindowTerminalState *strongself = weakself;
            
            bool newtitle = false;
            strongself->m_Screen->Lock();
            for(int i = 0; i < _sz; ++i)
            {
                int flags = 0;

                strongself->m_Parser->EatByte(((const char*)_d)[i], flags);

                if(flags & TermParser::Result_ChangedTitle)
                    newtitle = true;
            }
        
            strongself->m_Parser->Flush();
            strongself->m_Screen->Unlock();
        
            //            tmb.Reset("Parsed in: ");
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongself->m_View adjustSizes:false];
                [strongself->m_View setNeedsDisplay:true];
                if(newtitle)
                    [strongself UpdateTitle];
            });
        }
    });
    
    m_Task->SetOnBashPrompt(^(const char *_cwd){
        if(weakself != nil)
        {
            __strong MainWindowTerminalState *strongself = weakself;
            strongself->m_Screen->SetTitle("");
            [strongself UpdateTitle];
        }
    });
    
    [self.window makeFirstResponder:m_View];
    [self UpdateTitle];
}


- (void) UpdateTitle
{
    NSString *title = 0;
    
    m_Screen->Lock();
    if(strlen(m_Screen->Title()) > 0)
        title = [NSString stringWithUTF8String:m_Screen->Title()];
    m_Screen->Unlock();
    
    if(title == 0)
    {
        m_Task->Lock();
        title = [NSString stringWithUTF8String:m_Task->CWD()];
        m_Task->Unlock();
    }

    self.window.title = title;
}

- (void) Resigned
{
    
    
    // remove handlers with references to self
    m_Task->SetOnChildOutput(0);
    m_Task->SetOnBashPrompt(0);
    
//    NSLog(@"%ld", CFGetRetainCount((__bridge CFTypeRef)self));
}

- (void) ChDir:(const char*)_new_dir
{
    m_Task->ChDir(_new_dir);
}

- (void) Execute:(const char *)_short_fn at:(const char*)_at
{
    m_Task->Execute(_short_fn, _at);
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    NSRect scrollRect;
    scrollRect = [self documentVisibleRect];
    scrollRect.origin.y -= [theEvent deltaY] * [self verticalLineScroll];
    [[self documentView] scrollRectToVisible: scrollRect];
}

- (bool)WindowShouldClose:(MainWindowController*)sender
{
//    NSLog(@"1! %ld", CFGetRetainCount((__bridge CFTypeRef)self));
    
    if(m_Task->State() == TermTask::StateDead ||
       m_Task->State() == TermTask::StateInactive ||
       m_Task->State() == TermTask::StateShell)
        return true;
    
    vector<string> children;
    m_Task->GetChildrenList(children);
    if(children.empty())
        return true;

    MessageBox *dialog = [[MessageBox alloc] init];
    [dialog setMessageText:@"Do you want to close this window?"];
    NSMutableString *cap = [NSMutableString new];
    [cap appendString:@"Closing this window will terminate the running processes: "];
    for(int i = 0; i < children.size(); ++i)
    {
        [cap appendString:[NSString stringWithUTF8String:children[i].c_str()]];
        if(i != children.size() - 1)
            [cap appendString:@", "];
    }
    [cap appendString:@"."];
    [dialog setInformativeText:cap];
    [dialog addButtonWithTitle:@"Terminate And Close"];
    [dialog addButtonWithTitle:@"Cancel"];
    
//    NSWindow *wnd = self.windo
//    __weak MainWindowTerminalState *weakself = self;
    [dialog ShowSheetWithHandler:self.window handler:^(int result) {
        if (result == NSAlertFirstButtonReturn)
        {
//            NSLog(@"3! %ld", CFGetRetainCount((__bridge CFTypeRef)wself));
            [dialog.window orderOut:nil];
//            [wnd close];
            [sender.window close];
        }
    }];
 

/*    NSLog(@"!! %ld", CFGetRetainCount((__bridge CFTypeRef)self));
    __weak MainWindowTerminalState *wself = self;
    NSLog(@"!!! %ld", CFGetRetainCount((__bridge CFTypeRef)self));
    
    NSWindow *w = self.window;
    dispatch_async(dispatch_get_main_queue(), ^{
        [w close];
    });*/
    
//    NSLog(@"2! %ld", CFGetRetainCount((__bridge CFTypeRef)self));
    
    return false;
}

- (void)frameDidChange
{
    if(self.frame.size.width != m_View.frame.size.width)
    {
        NSRect dr = m_View.frame;
        dr.size.width = self.frame.size.width;
        [m_View setFrame:dr];
    }
    
    int sy = floor(self.frame.size.height / [m_View FontCache]->Height());
    int sx = floor(m_View.frame.size.width / [m_View FontCache]->Width());

    m_Screen->ResizeScreen(sx, sy);
    m_Task->ResizeWindow(sx, sy);
    m_Parser->Resized();
    
    [m_View adjustSizes:true];
}

- (IBAction)paste:(id)sender
{
    if(m_Task->State() == TermTask::StateDead ||
       m_Task->State() == TermTask::StateInactive )
        return;

    NSPasteboard *paste_board = [NSPasteboard generalPasteboard];
    NSString *best_type = [paste_board availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]];
    if(!best_type)
        return;
    
    NSString *text = [paste_board stringForType:NSStringPboardType];
    if(!text)
        return;

    const char* utf8str = [text UTF8String];
    m_Task->WriteChildInput(utf8str, (int)strlen(utf8str));
}

- (bool) IsAnythingRunning
{
    return m_Task->State() == TermTask::StateProgramExternal ||
           m_Task->State() == TermTask::StateProgramInternal;
}

- (void) Terminate
{
    m_Task->Terminate();
}

- (bool) GetCWD:(char *)_cwd
{
    if(m_Task->State() == TermTask::StateInactive ||
       m_Task->State() == TermTask::StateDead)
        return false;
    
    if(strlen(m_Task->CWD()) == 0)
       return 0;
    
    strcpy(_cwd, m_Task->CWD());
    return true;
}

- (IBAction)OnShowTerminal:(id)sender
{
    [(MainWindowController*)[[self window] delegate] ResignAsWindowState:self];
}

@end

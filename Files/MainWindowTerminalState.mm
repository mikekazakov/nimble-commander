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
        [self setHasVerticalScroller:YES];
        [self setBorderType:NSNoBorder];
        [self setVerticalScrollElasticity:NSScrollElasticityNone];
        [self setScrollsDynamically:false];
        [[self contentView] setCopiesOnScroll:NO];
        [[self contentView] setCanDrawConcurrently:false];
        [[self contentView] setDrawsBackground:false];
        
        strcpy(m_InitalWD, "/");
        GetUserHomeDirectoryPath(m_InitalWD);
        
        m_View = [[TermView alloc] initWithFrame:self.frame];
        [self setDocumentView:m_View];
        
        m_Task = new TermTask;
        m_Screen = new TermScreen([m_View SymbWidth], [m_View SymbHeight]);
        m_Parser = new TermParser(m_Screen, m_Task);
        [m_View AttachToScreen:m_Screen];
        [m_View AttachToParser:m_Parser];
    }
    return self;
}

- (void) dealloc
{
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
    strcpy(m_InitalWD, _wd);
}

- (void) Assigned
{
    // need right CWD here
    if(m_Task->State() == TermTask::StateInactive)
        m_Task->Launch(/*"/Users/migun/"*/ m_InitalWD, [m_View SymbWidth], [m_View SymbHeight]);
    
    m_Task->SetOnChildOutput(^(const void* _d, int _sz){
        //            MachTimeBenchmark tmb;
        m_Screen->Lock();
        for(int i = 0; i < _sz; ++i)
            m_Parser->EatByte(((const char*)_d)[i]);
        
        m_Parser->Flush();
        m_Screen->Unlock();
        
        //            tmb.Reset("Parsed in: ");
        dispatch_async(dispatch_get_main_queue(), ^{
            [m_View adjustSizes];
            [m_View setNeedsDisplay:true];
        });
    });
    
    m_Task->SetOnBashPrompt(^(const char *_cwd){
//        char tmp[1024];
//        memcpy(tmp, _d, _sz);
//        tmp[_sz] = 0;
        /*            [self.CommandText setStringValue:[NSString stringWithUTF8String:tmp]];*/
//        printf("BASH cwd: %s\n", _cwd);
    });
    
    
    
    
    
    [self.window makeFirstResponder:m_View];
    
    
 //   [self UpdateTitle];
}



- (void) Resigned
{
    // remove handlers with references to self
    m_Task->SetOnChildOutput(0);
    m_Task->SetOnBashPrompt(0);
}

- (void) ChDir:(const char*)_new_dir
{
    m_Task->ChDir(_new_dir);
}

- (void) Execute:(const char *)_short_fn
{
    m_Task->Execute(_short_fn);
}

- (void)cancelOperation:(id)sender
{
    [(MainWindowController*)[[self window] delegate] ResignAsWindowState:self];
}

@end

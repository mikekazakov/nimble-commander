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
//    NSScrollView    *m_ScrollView;
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        [self setHasVerticalScroller:YES];
        [self setBorderType:NSNoBorder];
        
        m_View = [[TermView alloc] initWithFrame:self.frame];

        [self setDocumentView:m_View];
        [self setVerticalScrollElasticity:NSScrollElasticityNone];
        [self setScrollsDynamically:false];        
        [[self contentView] setCopiesOnScroll:NO];
        [[self contentView] setCanDrawConcurrently:false];
        [[self contentView] setDrawsBackground:false];
        
        m_Task = new TermTask;
        m_Screen = new TermScreen([m_View SymbWidth], [m_View SymbHeight]);
        m_Parser = new TermParser(m_Screen, m_Task);
        [m_View AttachToScreen:m_Screen];
        [m_View AttachToParser:m_Parser];

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
//                [[self contentView] setNeedsDisplay:true];
//                [self setNeedsDisplay:true];
            });
//            [self setNeedsDisplay:true];
//            [[self contentView] setNeedsDisplay:true];
        });

        m_Task->SetOnBashPrompt(^(const void* _d, int _sz){
            char tmp[1024];
            memcpy(tmp, _d, _sz);
            tmp[_sz] = 0;
/*            [self.CommandText setStringValue:[NSString stringWithUTF8String:tmp]];*/
//            printf("new BASH cwd: %s", tmp);
        });
        
        m_Task->Launch("/Users/migun/", [m_View SymbWidth], [m_View SymbHeight]);
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

- (void) Assigned
{
    [self.window makeFirstResponder:m_View];
 //   [self UpdateTitle];
}

- (void)cancelOperation:(id)sender
{
    [(MainWindowController*)[[self window] delegate] ResignAsWindowState:self];
}

@end

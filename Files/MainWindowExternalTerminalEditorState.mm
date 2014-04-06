//
//  MainWindowExternalTerminalEditorState.m
//  Files
//
//  Created by Michael G. Kazakov on 04.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "TermSingleTask.h"
#import "TermScreen.h"
#import "TermParser.h"
#import "TermView.h"
#import "FontCache.h"
#import "Common.h"
#import "MainWindowController.h"
#import "MainWindowExternalTerminalEditorState.h"


@implementation MainWindowExternalTerminalEditorState
{
    unique_ptr<TermSingleTask>  m_Task;
    unique_ptr<TermScreen>      m_Screen;
    unique_ptr<TermParser>      m_Parser;
    TermView                   *m_View;
    string                      m_BinaryPath;
    string                      m_Params;
}

- (id)initWithFrameAndParams:(NSRect)frameRect
                      binary:(string)_binary_path
                      params:(string)_params
{
    self = [super initWithFrame:frameRect];
    if (self) {
        m_BinaryPath = _binary_path;
        m_Params = _params;
        m_View = [[TermView alloc] initWithFrame:self.frame];
        self.documentView = m_View;
/*        self.hasVerticalScroller = true;
        self.borderType = NSNoBorder;
        self.verticalScrollElasticity = NSScrollElasticityNone;
        self.scrollsDynamically = true;
        self.contentView.copiesOnScroll = false;
        self.contentView.canDrawConcurrently = false;
        self.contentView.drawsBackground = false;
        
        __weak MainWindowExternalTerminalEditorState *weakself = self;
        
        m_Task = make_unique<TermSingleTask>();
        auto task_raw_ptr = m_Task.get();
        m_Screen = make_unique<TermScreen>(floor(frameRect.size.width / [m_View FontCache]->Width()),
                                           floor(frameRect.size.height / [m_View FontCache]->Height()));
        m_Parser = make_unique<TermParser>(m_Screen.get(),
                                           ^(const void* _d, int _sz){
                                                task_raw_ptr->WriteChildInput(_d, _sz);
                                           });
        [m_View AttachToScreen:m_Screen.get()];
        [m_View AttachToParser:m_Parser.get()];

        m_Task->SetOnChildOutput(^(const void* _d, int _sz){
            if(MainWindowExternalTerminalEditorState *strongself = weakself)
            {
                //            bool newtitle = false;
                strongself->m_Screen->Lock();
                for(int i = 0; i < _sz; ++i)
                {
                    int flags = 0;
                    
                    strongself->m_Parser->EatByte(((const char*)_d)[i], flags);
                    
                    //                if(flags & TermParser::Result_ChangedTitle)
                    //                    newtitle = true;
                }
                
                strongself->m_Parser->Flush();
                strongself->m_Screen->Unlock();
                
                //            tmb.Reset("Parsed in: ");
                dispatch_to_main_queue( ^{
                    [strongself->m_View adjustSizes:false];
                    [strongself->m_View setNeedsDisplay:true];
                    //                if(newtitle)
                    //                    [strongself UpdateTitle];
                });
            }
        });
        m_Task->SetOnChildDied(^{
            dispatch_to_main_queue( ^{
                if(MainWindowExternalTerminalEditorState *strongself = weakself)
                    [(MainWindowController*)strongself.window.delegate ResignAsWindowState:strongself];
            });
        });

        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];
 */
    }
    return self;
}

- (void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (NSView*) ContentView
{
    return self;
}

- (void) Assigned
{
//    m_Task->Launch(m_BinaryPath.c_str(), m_Params.c_str(), m_Screen->Width(), m_Screen->Height());
    [self.window makeFirstResponder:m_View];
//    [self UpdateTitle];
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

- (IBAction)OnShowTerminal:(id)sender
{
    [(MainWindowController*)self.window.delegate ResignAsWindowState:self];
}

@end

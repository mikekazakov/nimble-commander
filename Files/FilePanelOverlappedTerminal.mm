//
//  FilePanelOverlappedTerminal.m
//  Files
//
//  Created by Michael G. Kazakov on 16/07/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "TermShellTask.h"
#import "TermScreen.h"
#import "TermParser.h"
#import "TermView.h"
#import "TermScrollView.h"
#import "FontCache.h"
#import "Common.h"
#import "common_paths.h"
#import "FilePanelOverlappedTerminal.h"

@implementation FilePanelOverlappedTerminal
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
        
        m_TermScrollView = [[TermScrollView alloc] initWithFrame:self.bounds];
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
        
        __weak FilePanelOverlappedTerminal *weakself = self;
        
        m_Task->SetOnChildOutput([=](const void* _d, int _sz){
            if(FilePanelOverlappedTerminal *strongself = weakself) {
                strongself->m_TermScrollView.screen.Lock();
                strongself->m_Parser->EatBytes((const unsigned char*)_d, _sz);
                strongself->m_TermScrollView.screen.Unlock();
                [strongself->m_TermScrollView.view.FPSDrawer invalidate];
                
                dispatch_to_main_queue( [=]{
                    [strongself->m_TermScrollView.view adjustSizes:false];
                });
            }
        });
    }
    return self;
}

- (double) bottomGapForLines:(int)_lines_amount
{
    if(_lines_amount < 1)
        return 0;
    
    const int lines_on_screen = m_TermScrollView.screen.Height();
    if( _lines_amount >= lines_on_screen )
        return self.bounds.size.height;
    
    int line_delta = lines_on_screen - _lines_amount;
    return self.bounds.size.height - m_TermScrollView.view.fontCache.Height() * line_delta;
}

- (int) totalScreenLines
{
    return m_TermScrollView.screen.Height();
}

- (TermShellTask::TaskState) state
{
    return m_Task->State();
}

- (void) runShell
{
    auto s = m_Task->State();
    if( s == TermShellTask::TaskState::Inactive ||
        s == TermShellTask::TaskState::Dead )
        m_Task->Launch(m_InitalWD.c_str(),
                       m_TermScrollView.screen.Width(),
                       m_TermScrollView.screen.Height());
}

@end

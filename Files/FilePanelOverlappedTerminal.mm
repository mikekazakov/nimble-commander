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

static auto g_BashPromptInputDelay = 10ms;

@implementation FilePanelOverlappedTerminal
{
    TermScrollView             *m_TermScrollView;
    unique_ptr<TermShellTask>   m_Task;
    unique_ptr<TermParser>      m_Parser;
    string                      m_InitalWD;
    function<void()>            m_OnShellCWDChanged;
    int                         m_BashCommandStartX;
    int                         m_BashCommandStartY;
}

@synthesize onShellCWDChanged = m_OnShellCWDChanged;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        m_BashCommandStartX = m_BashCommandStartY = numeric_limits<int>::max();
        m_InitalWD = CommonPaths::Get(CommonPaths::Home);
        
        m_TermScrollView = [[TermScrollView alloc] initWithFrame:self.bounds];
        m_TermScrollView.translatesAutoresizingMaskIntoConstraints = false;
        m_TermScrollView.view.reportsSizeByOccupiedContent = true;
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
        m_Task->SetOnBashPrompt([=](const char *_cwd, bool _changed){
            if(FilePanelOverlappedTerminal *strongself = weakself) {
                dispatch_to_main_queue_after(g_BashPromptInputDelay, [=]{
                    [strongself guessWhereCommandLineIs];
                });
                
                if(_changed)
                    dispatch_to_main_queue([=]{
                        if(strongself->m_OnShellCWDChanged)
                            strongself->m_OnShellCWDChanged();
                    });
            }
        });
    }
    return self;
}

- (void) guessWhereCommandLineIs
{
    m_TermScrollView.screen.Lock();

//    cout << m_TermScrollView.screen.Buffer().DumpScreenAsANSI() << endl;
//    printf( "cursor is at (%d, %d)\n",
//           m_TermScrollView.screen.CursorX(),
//           m_TermScrollView.screen.CursorY());
    m_BashCommandStartX = m_TermScrollView.screen.CursorX();
    m_BashCommandStartY = m_TermScrollView.screen.CursorY();
    
    m_TermScrollView.screen.Unlock();
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

- (void) runShell:(const string&)_initial_wd;
{
    if( !_initial_wd.empty() )
        m_InitalWD = _initial_wd;
        
    auto s = m_Task->State();
    if( s == TermShellTask::TaskState::Inactive ||
        s == TermShellTask::TaskState::Dead )
        m_Task->Launch(m_InitalWD.c_str(),
                       m_TermScrollView.screen.Width(),
                       m_TermScrollView.screen.Height());
}

- (void) changeWorkingDirectory:(const string&)_new_dir
{
    m_Task->ChDir(_new_dir.c_str());
}

- (void) focusTerminal
{
    [self.window makeFirstResponder:m_TermScrollView.view];
}

- (string) cwd
{
    return m_Task->CWD();
}

- (void) feedShellWithInput:(const string&)_input
{
    if( self.state != TermShellTask::TaskState::Shell )
        return;
    
    printf("feedShellWithInput, virgin=%s\n", self.isShellVirgin ? "true" : "false");
    
    const size_t sz = 4096;
    char escaped[sz];
    int r = TermShellTask::EscapeShellFeed(_input.c_str(), escaped, sz);
    if(r >= 0) {
        m_Task->WriteChildInput(escaped, r);
        m_Task->WriteChildInput(" ", 1);
    }
}

- (void) commitShell
{
    if( self.state != TermShellTask::TaskState::Shell )
        return;
    m_Task->WriteChildInput("\n", strlen("\n"));
}

- (bool) isShellVirgin
{
    if( self.state != TermShellTask::TaskState::Shell )
        return false;
    
    auto virgin = false;
    m_TermScrollView.screen.Lock();
    if( auto line = m_TermScrollView.screen.Buffer().LineFromNo( m_BashCommandStartY ) ) {
        auto i = min( max(begin(line), begin(line)+m_BashCommandStartX), end(line) );
        auto e = end( line );
        if( !TermScreenBuffer::HasOccupiedChars(i, e) )
            virgin = true;
    }
    m_TermScrollView.screen.Unlock();
    
    return virgin;
}

@end

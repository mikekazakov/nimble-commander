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

static const auto g_BashPromptInputDelay = 10ms;
static const auto g_LongProcessDelay = 150ms;

@implementation FilePanelOverlappedTerminal
{
    TermScrollView             *m_TermScrollView;
    unique_ptr<TermShellTask>   m_Task;
    unique_ptr<TermParser>      m_Parser;
    string                      m_InitalWD;
    function<void()>            m_OnShellCWDChanged;
    function<void()>            m_OnLongTaskStarted;
    function<void()>            m_OnLongTaskFinished;
    int                         m_BashCommandStartX;
    int                         m_BashCommandStartY;
    volatile bool               m_RunningLongTask;
}

@synthesize onShellCWDChanged = m_OnShellCWDChanged;
@synthesize onLongTaskStarted = m_OnLongTaskStarted;
@synthesize onLongTaskFinished = m_OnLongTaskFinished;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        m_BashCommandStartX = m_BashCommandStartY = numeric_limits<int>::max();
        m_RunningLongTask = false;
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
            [(FilePanelOverlappedTerminal*)weakself onChildOutput:_d size:_sz];
        });
        m_Task->SetOnBashPrompt([=](const char *_cwd, bool _changed){
            [(FilePanelOverlappedTerminal*)weakself onBashPrompt:_cwd cwdChanged:_changed];
        });
        m_Task->SetOnStateChange([=](TermShellTask::TaskState _state){
            [(FilePanelOverlappedTerminal*)weakself onTaskStateChanged:_state];
        });
    }
    return self;
}

- (void) onChildOutput:(const void*)_d size:(int)_sz
{
    m_TermScrollView.screen.Lock();
    m_Parser->EatBytes((const unsigned char*)_d, _sz);
    m_TermScrollView.screen.Unlock();
    [m_TermScrollView.view.FPSDrawer invalidate];
    
    dispatch_to_main_queue( [=]{
        [m_TermScrollView.view adjustSizes:false];
    });
}

- (void) onBashPrompt:(const char*)_cwd cwdChanged:(bool)_changed
{
    dispatch_to_main_queue_after(g_BashPromptInputDelay, [=]{
        [self guessWhereCommandLineIs];
    });
    
    if(_changed)
        dispatch_to_main_queue([=]{
            if(m_OnShellCWDChanged)
                m_OnShellCWDChanged();
        });
}

- (void) onTaskStateChanged:(TermShellTask::TaskState)_state
{
    if( _state == TermShellTask::TaskState::ProgramInternal ||
        _state == TermShellTask::TaskState::ProgramExternal ) {
        
        dispatch_to_main_queue_after(g_LongProcessDelay, [=]{
            if( m_Task->State() == TermShellTask::TaskState::ProgramInternal ||
               m_Task->State() == TermShellTask::TaskState::ProgramExternal ) {
                m_RunningLongTask = true;
                if( m_OnLongTaskStarted )
                    m_OnLongTaskStarted();
            }
        });
    }
    else {
        if( m_RunningLongTask ) {
            m_RunningLongTask = false;
            dispatch_to_main_queue([=]{
                if( m_OnLongTaskFinished )
                    m_OnLongTaskFinished();
            });
        }
    }
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

    auto esc = TermTask::EscapeShellFeed( _input );
    if( !esc.empty() ) {
        m_Task->WriteChildInput( esc.c_str(), (int)esc.length() );
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

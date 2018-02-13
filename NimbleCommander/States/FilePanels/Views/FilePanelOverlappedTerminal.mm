// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/CommonPaths.h>
#include <Utility/FontCache.h>
#include <Term/ShellTask.h>
#include <Term/Screen.h>
#include <Term/Parser.h>
#include <Term/View.h>
#include <Term/ScrollView.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/States/Terminal/SettingsAdaptor.h>
#include "FilePanelOverlappedTerminal.h"

using namespace nc;
using namespace nc::term;

static const auto g_UseDefault = "terminal.useDefaultLoginShell";
static const auto g_CustomPath = "terminal.customShellPath";
static const auto g_BashPromptInputDelay = 10ms;
static const auto g_TaskStartInputDelay = 50ms;
static const auto g_LongProcessDelay = 100ms;

@implementation FilePanelOverlappedTerminal
{
    NCTermScrollView           *m_TermScrollView;
    unique_ptr<ShellTask>       m_Task;
    unique_ptr<Parser>          m_Parser;
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
        m_InitalWD = CommonPaths::Home();
        
        m_TermScrollView = [[NCTermScrollView alloc] initWithFrame:self.bounds
                                                       attachToTop:false
                                                          settings:TerminalSettings()];
        m_TermScrollView.translatesAutoresizingMaskIntoConstraints = false;
        m_TermScrollView.view.reportsSizeByOccupiedContent = true;
        [self addSubview:m_TermScrollView];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_TermScrollView]-(==0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(m_TermScrollView)]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_TermScrollView]-(==0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(m_TermScrollView)]];
        
        m_Task = make_unique<ShellTask>();
        if( !GlobalConfig().GetBool(g_UseDefault) )
            if( auto s = GlobalConfig().GetString(g_CustomPath) )
                m_Task->SetShellPath(*s);
        
        auto task_ptr = m_Task.get();
        m_Parser = make_unique<Parser>(m_TermScrollView.screen,
                                           [=](const void* _d, int _sz){
                                               task_ptr->WriteChildInput( string_view((const char*)_d, _sz) );
                                           });
        m_Parser->SetTaskScreenResize([=](int sx, int sy) {
            task_ptr->ResizeWindow(sx, sy);
        });
        [m_TermScrollView.view AttachToParser:m_Parser.get()];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
        __weak FilePanelOverlappedTerminal *weakself = self;
        m_Task->SetOnChildOutput([=](const void* _d, int _sz){
            [(FilePanelOverlappedTerminal*)weakself onChildOutput:_d size:_sz];
        });
        m_Task->SetOnPwdPrompt([=](const char *_cwd, bool _changed){
            [(FilePanelOverlappedTerminal*)weakself onBashPrompt:_cwd cwdChanged:_changed];
        });
        m_Task->SetOnStateChange([=](ShellTask::TaskState _state){
            [(FilePanelOverlappedTerminal*)weakself onTaskStateChanged:_state];
        });
#pragma clang diagnostic pop
    }
    return self;
}

- (void) onChildOutput:(const void*)_d size:(int)_sz
{
    if( auto lock = m_TermScrollView.screen.AcquireLock() )
        m_Parser->EatBytes((const unsigned char*)_d, _sz);
    [m_TermScrollView.view.fpsDrawer invalidate];
    
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

- (void) onTaskStateChanged:(ShellTask::TaskState)_state
{
    if( _state == ShellTask::TaskState::ProgramInternal ||
        _state == ShellTask::TaskState::ProgramExternal ) {
        dispatch_to_main_queue_after(g_TaskStartInputDelay, [=]{
            int task_pid = m_Task->ShellChildPID();
            if(task_pid >= 0)
                dispatch_to_main_queue_after(g_LongProcessDelay, [=]{
                    if( (m_Task->State() == ShellTask::TaskState::ProgramInternal ||
                         m_Task->State() == ShellTask::TaskState::ProgramExternal) &&
                         m_Task->ShellChildPID() == task_pid ) {
                        m_RunningLongTask = true;
                        if( m_OnLongTaskStarted )
                            m_OnLongTaskStarted();
                    }
                });
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
//    m_TermScrollView.screen.Lock();

//    cout << m_TermScrollView.screen.Buffer().DumpScreenAsANSI() << endl;
//    printf( "cursor is at (%d, %d)\n",
//           m_TermScrollView.screen.CursorX(),
//           m_TermScrollView.screen.CursorY());
    auto lock = m_TermScrollView.screen.AcquireLock();
    m_BashCommandStartX = m_TermScrollView.screen.CursorX();
    m_BashCommandStartY = m_TermScrollView.screen.CursorY();
    
//    m_TermScrollView.screen.Unlock();
}

- (double) bottomGapForLines:(int)_lines_amount
{
    if(_lines_amount < 1)
        return 0;
    auto sz = [NCTermView insetSize:self.bounds.size];
    auto font_height = m_TermScrollView.view.fontCache.Height();
    auto residual = fmod(sz.height, font_height);
    return font_height * _lines_amount + residual + NCTermView.insets.bottom;
}

- (int) totalScreenLines
{
    return m_TermScrollView.screen.Height();
}

- (ShellTask::TaskState) state
{
    return m_Task->State();
}

- (void) runShell:(const string&)_initial_wd;
{
    if( !_initial_wd.empty() )
        m_InitalWD = _initial_wd;
        
    const auto s = m_Task->State();
    if( s == ShellTask::TaskState::Inactive ||
        s == ShellTask::TaskState::Dead ) {
        m_Task->ResizeWindow( m_TermScrollView.screen.Width(), m_TermScrollView.screen.Height() );
        m_Task->Launch( m_InitalWD.c_str() );
    }
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
    if( self.state != ShellTask::TaskState::Shell )
        return;

    auto esc = Task::EscapeShellFeed( _input );
    if( !esc.empty() ) {
        esc += " ";
        m_Task->WriteChildInput( esc );
    }
}

- (void) commitShell
{
    if( self.state != ShellTask::TaskState::Shell )
        return;
    m_Task->WriteChildInput( "\n" );
}

- (bool) isShellVirgin
{
    if( self.state != ShellTask::TaskState::Shell )
        return false;
    
    auto virgin = false;
    auto lock = m_TermScrollView.screen.AcquireLock();
//    m_TermScrollView.screen.Lock();
    if( auto line = m_TermScrollView.screen.Buffer().LineFromNo( m_BashCommandStartY ) ) {
        auto i = min( max(begin(line), begin(line)+m_BashCommandStartX), end(line) );
        auto e = end( line );
        if( !ScreenBuffer::HasOccupiedChars(i, e) )
            virgin = true;
    }
//    m_TermScrollView.screen.Unlock();
    
    return virgin;
}

- (void) runPasteMenu:(const vector<string>&)_strings
{
    NSMenu *menu = [[NSMenu alloc] init];
    
    menu.font = m_TermScrollView.view.font;
    
    for(auto &i:_strings) {
        NSMenuItem *it = [[NSMenuItem alloc] init];
        it.title = [NSString stringWithUTF8StdString:i];
        it.target = self;
        it.action = @selector(handlePasteMenuItem:);
        [menu addItem:it];
    }
    
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, 0) inView:self];
}

- (void) handlePasteMenuItem:(id)_sender
{
    if( auto it = objc_cast<NSMenuItem>(_sender) )
        [self feedShellWithInput:it.title.fileSystemRepresentationSafe];
}

- (bool) canFeedShellWithKeyDown:(NSEvent *)event
{
    if( self.state != ShellTask::TaskState::Shell )
        return false;
    
    static NSCharacterSet *chars;
    static once_flag once;
    call_once(once, []{
        NSMutableCharacterSet *un = [NSMutableCharacterSet new];
        [un formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"\u007f"]];
        chars = un;
    });
    
    NSString *str = event.characters;
    if( str.length == 0)
        return false;
    
    bool isin = [chars characterIsMember:[str characterAtIndex:0]]; // consider uing UTF-32 here
    return isin;
}

- (bool) feedShellWithKeyDown:(NSEvent *)event
{
    if( [self canFeedShellWithKeyDown:event] ) {
        [m_TermScrollView.view keyDown:event];
        return true;
    }
    
    return false;
}

@end

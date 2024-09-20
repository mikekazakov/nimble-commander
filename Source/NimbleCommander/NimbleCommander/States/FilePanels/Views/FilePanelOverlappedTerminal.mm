// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/CommonPaths.h>
#include <Term/ShellTask.h>
#include <Term/Screen.h>
#include <Term/ParserImpl.h>
#include <Term/View.h>
#include <Term/ScrollView.h>
#include <Term/InputTranslatorImpl.h>
#include <Term/InterpreterImpl.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/States/Terminal/SettingsAdaptor.h>
#include "FilePanelOverlappedTerminal.h"
#include <Base/dispatch_cpp.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>
#include <algorithm>

using namespace nc;
using namespace nc::term;
using namespace std::literals;

static const auto g_UseDefault = "terminal.useDefaultLoginShell";
static const auto g_CustomPath = "terminal.customShellPath";
static const auto g_BashPromptInputDelay = 10ms;
static const auto g_TaskStartInputDelay = 50ms;
static const auto g_LongProcessDelay = 100ms;

@implementation FilePanelOverlappedTerminal {
    NCTermScrollView *m_TermScrollView;
    std::unique_ptr<ShellTask> m_Task;
    std::unique_ptr<Parser> m_Parser;
    std::unique_ptr<InputTranslator> m_InputTranslator;
    std::unique_ptr<Interpreter> m_Interpreter;
    std::string m_InitalWD;
    std::function<void()> m_OnShellCWDChanged;
    std::function<void()> m_OnLongTaskStarted;
    std::function<void()> m_OnLongTaskFinished;
    int m_BashCommandStartX;
    int m_BashCommandStartY;
    volatile bool m_RunningLongTask;
}

@synthesize onShellCWDChanged = m_OnShellCWDChanged;
@synthesize onLongTaskStarted = m_OnLongTaskStarted;
@synthesize onLongTaskFinished = m_OnLongTaskFinished;

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_BashCommandStartX = m_BashCommandStartY = std::numeric_limits<int>::max();
        m_RunningLongTask = false;
        m_InitalWD = nc::base::CommonPaths::Home();
        __weak FilePanelOverlappedTerminal *weak_self = self;

        m_TermScrollView = [[NCTermScrollView alloc] initWithFrame:self.bounds
                                                       attachToTop:false
                                                          settings:TerminalSettings()];
        m_TermScrollView.translatesAutoresizingMaskIntoConstraints = false;
        m_TermScrollView.view.reportsSizeByOccupiedContent = true;
        m_TermScrollView.overlapped = true;
        [self addSubview:m_TermScrollView];
        [self addConstraints:[NSLayoutConstraint
                                 constraintsWithVisualFormat:@"|-(==0)-[m_TermScrollView]-(==0)-|"
                                                     options:0
                                                     metrics:nil
                                                       views:NSDictionaryOfVariableBindings(m_TermScrollView)]];
        [self addConstraints:[NSLayoutConstraint
                                 constraintsWithVisualFormat:@"V:|-(==0)-[m_TermScrollView]-(==0)-|"
                                                     options:0
                                                     metrics:nil
                                                       views:NSDictionaryOfVariableBindings(m_TermScrollView)]];

        m_Task = std::make_unique<ShellTask>();
        if( !GlobalConfig().GetBool(g_UseDefault) )
            if( GlobalConfig().Has(g_CustomPath) )
                m_Task->SetShellPath(GlobalConfig().GetString(g_CustomPath));

        auto task_ptr = m_Task.get();

        // input translator
        m_InputTranslator = std::make_unique<InputTranslatorImpl>();
        m_InputTranslator->SetOuput([=](std::span<const std::byte> _bytes) {
            task_ptr->WriteChildInput(std::string_view(reinterpret_cast<const char *>(_bytes.data()), _bytes.size()));
        });

        // parser
        ParserImpl::Params parser_params;
        parser_params.error_log = [](std::string_view _error) { std::cerr << _error << '\n'; };
        m_Parser = std::make_unique<ParserImpl>(parser_params);

        // interpreter
        m_Interpreter = std::make_unique<InterpreterImpl>(m_TermScrollView.screen);
        m_Interpreter->SetOuput([=](std::span<const std::byte> _bytes) {
            task_ptr->WriteChildInput(std::string_view(reinterpret_cast<const char *>(_bytes.data()), _bytes.size()));
        });
        m_Interpreter->SetBell([] { NSBeep(); });
        m_Interpreter->SetTitle([](const std::string &, Interpreter::TitleKind) { /* deliberately nothing*/ });
        m_Interpreter->SetInputTranslator(m_InputTranslator.get());
        m_Interpreter->SetShowCursorChanged([weak_self](bool _show) {
            FilePanelOverlappedTerminal *const me = weak_self;
            me->m_TermScrollView.view.showCursor = _show;
        });
        m_Interpreter->SetRequstedMouseEventsChanged([weak_self](Interpreter::RequestedMouseEvents _events) {
            FilePanelOverlappedTerminal *const me = weak_self;
            me->m_TermScrollView.view.mouseEvents = _events;
        });
        m_Interpreter->SetScreenResizeAllowed(false);

        [m_TermScrollView.view AttachToInputTranslator:m_InputTranslator.get()];
        m_TermScrollView.onScreenResized = [weak_self](int _sx, int _sy) {
            FilePanelOverlappedTerminal *const me = weak_self;
            me->m_Interpreter->NotifyScreenResized();
            me->m_Task->ResizeWindow(_sx, _sy);
        };

        m_Task->SetOnChildOutput([weak_self](const void *_d, int _sz) {
            [static_cast<FilePanelOverlappedTerminal *>(weak_self) onChildOutput:_d size:_sz];
        });
        m_Task->SetOnPwdPrompt([weak_self](const char *_cwd, bool _changed) {
            [static_cast<FilePanelOverlappedTerminal *>(weak_self) onBashPrompt:_cwd cwdChanged:_changed];
        });
        m_Task->SetOnStateChange([weak_self](ShellTask::TaskState _state) {
            [static_cast<FilePanelOverlappedTerminal *>(weak_self) onTaskStateChanged:_state];
        });
    }
    return self;
}

- (void)onChildOutput:(const void *)_d size:(int)_sz
{
    dispatch_assert_background_queue();

    auto cmds = m_Parser->Parse({static_cast<const std::byte *>(_d), static_cast<size_t>(_sz)});
    if( cmds.empty() )
        return;

    __weak FilePanelOverlappedTerminal *weak_self = self;

    dispatch_to_main_queue([weak_self, cmds = std::move(cmds)] {
        FilePanelOverlappedTerminal *const me = weak_self;
        if( auto lock = me->m_TermScrollView.screen.AcquireLock() )
            me->m_Interpreter->Interpret(cmds);
        [me->m_TermScrollView.view.fpsDrawer invalidate];
        [me->m_TermScrollView.view adjustSizes:false];
    });
}

- (void)onBashPrompt:(const char *) [[maybe_unused]] _cwd cwdChanged:(bool)_changed
{
    dispatch_assert_background_queue();
    dispatch_to_main_queue_after(g_BashPromptInputDelay, [=] { [self guessWhereCommandLineIs]; });

    if( _changed )
        dispatch_to_main_queue([=] {
            if( m_OnShellCWDChanged )
                m_OnShellCWDChanged();
        });
}

- (void)onTaskStateChanged:(ShellTask::TaskState)_state
{
    if( _state == ShellTask::TaskState::ProgramInternal || _state == ShellTask::TaskState::ProgramExternal ) {
        dispatch_to_main_queue_after(g_TaskStartInputDelay, [=] {
            const int task_pid = m_Task->ShellChildPID();
            if( task_pid >= 0 )
                dispatch_to_main_queue_after(g_LongProcessDelay, [=] {
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
            dispatch_to_main_queue([=] {
                if( m_OnLongTaskFinished )
                    m_OnLongTaskFinished();
            });
        }
    }
}

- (void)guessWhereCommandLineIs
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

- (double)bottomGapForLines:(int)_lines_amount
{
    if( _lines_amount < 1 )
        return 0;

    const auto screen_lines_amount = m_TermScrollView.screen.Height();
    const auto screen_line_index = screen_lines_amount - _lines_amount;
    if( screen_line_index < 0 )
        return m_TermScrollView.bounds.size.height;

    auto view_pt = [m_TermScrollView.view beginningOfScreenLine:screen_line_index];
    const auto local_pt = NSMakePoint(view_pt.x, self.frame.size.height - view_pt.y - m_TermScrollView.viewInsets.top);
    const auto gap = local_pt.y;
    return std::clamp(gap, 0., self.bounds.size.height);
}

- (int)totalScreenLines
{
    return m_TermScrollView.screen.Height();
}

- (ShellTask::TaskState)state
{
    return m_Task->State();
}

- (NCTermView *)termView
{
    return m_TermScrollView.view;
}

- (NCTermScrollView *)termScrollView
{
    return m_TermScrollView;
}

- (void)runShell:(const std::string &)_initial_wd
{
    if( !_initial_wd.empty() )
        m_InitalWD = _initial_wd;

    const auto s = m_Task->State();
    if( s == ShellTask::TaskState::Inactive || s == ShellTask::TaskState::Dead ) {
        m_Task->ResizeWindow(m_TermScrollView.screen.Width(), m_TermScrollView.screen.Height());
        m_Task->Launch(m_InitalWD.c_str());
    }
}

- (void)changeWorkingDirectory:(const std::string &)_new_dir
{
    m_Task->ChDir(_new_dir.c_str());
}

- (void)focusTerminal
{
    [self.window makeFirstResponder:m_TermScrollView.view];
}

- (std::string)cwd
{
    return m_Task->CWD();
}

- (void)feedShellWithInput:(const std::string &)_input
{
    if( self.state != ShellTask::TaskState::Shell )
        return;

    auto esc = Task::EscapeShellFeed(_input);
    if( !esc.empty() ) {
        esc += " ";
        m_Task->WriteChildInput(esc);
    }
}

- (void)commitShell
{
    if( self.state != ShellTask::TaskState::Shell )
        return;
    m_Task->WriteChildInput("\n");
}

- (bool)isShellVirgin
{
    if( self.state != ShellTask::TaskState::Shell )
        return false;

    auto virgin = false;
    auto lock = m_TermScrollView.screen.AcquireLock();
    if( auto line = m_TermScrollView.screen.Buffer().LineFromNo(m_BashCommandStartY); !line.empty() ) {
        auto i = std::min(std::max(begin(line), std::begin(line) + m_BashCommandStartX), std::end(line));
        auto e = std::end(line);
        virgin = std::all_of(i, e, [](const ScreenBuffer::Space &sp) { return sp.l == 0 || sp.l == ' '; });
    }

    return virgin;
}

- (void)runPasteMenu:(const std::vector<std::string> &)_strings
{
    NSMenu *menu = [[NSMenu alloc] init];

    menu.font = m_TermScrollView.view.font;

    for( auto &i : _strings ) {
        NSMenuItem *it = [[NSMenuItem alloc] init];
        it.title = [NSString stringWithUTF8StdString:i];
        it.target = self;
        it.action = @selector(handlePasteMenuItem:);
        [menu addItem:it];
    }

    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, 0) inView:self];
}

- (void)handlePasteMenuItem:(id)_sender
{
    if( auto it = objc_cast<NSMenuItem>(_sender) )
        [self feedShellWithInput:it.title.fileSystemRepresentationSafe];
}

- (bool)canFeedShellWithKeyDown:(NSEvent *)event
{
    if( self.state != ShellTask::TaskState::Shell )
        return false;

    static NSCharacterSet *chars;
    static std::once_flag once;
    std::call_once(once, [] {
        NSMutableCharacterSet *const un = [NSMutableCharacterSet new];
        [un formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"\u007f"]];
        chars = un;
    });

    NSString *str = event.characters;
    if( str.length == 0 )
        return false;

    bool isin = [chars characterIsMember:[str characterAtIndex:0]]; // consider uing UTF-32 here
    return isin;
}

- (bool)feedShellWithKeyDown:(NSEvent *)event
{
    if( [self canFeedShellWithKeyDown:event] ) {
        [m_TermScrollView.view keyDown:event];
        return true;
    }

    return false;
}

@end

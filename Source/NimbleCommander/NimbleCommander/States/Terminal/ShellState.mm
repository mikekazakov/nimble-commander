// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ShellState.h"
#include <Base/CommonPaths.h>
#include <Utility/NativeFSManager.h>
#include <Utility/PathManip.h>
#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <Utility/ActionsShortcutsManager.h>
#include <NimbleCommander/States/MainWindowController.h>
#include <Term/ShellTask.h>
#include <Term/Screen.h>
#include <Term/Log.h>
#include <Term/View.h>
#include <Term/ScrollView.h>
#include <Term/InputTranslatorImpl.h>
#include <Term/ParserImpl.h>
#include <Term/Settings.h>
#include <Term/InterpreterImpl.h>
#include <Term/ChildrenTracker.h>
#include "SettingsAdaptor.h"
#include <Base/dispatch_cpp.h>
#include <Utility/StringExtras.h>
#include <fmt/core.h>

using namespace nc;
using namespace nc::term;

static const auto g_UseDefault = "terminal.useDefaultLoginShell";
static const auto g_CustomPath = "terminal.customShellPath";

@implementation NCTermShellState {
    NCTermScrollView *m_TermScrollView;
    std::unique_ptr<ShellTask> m_Task;
    std::unique_ptr<InputTranslator> m_InputTranslator;
    std::unique_ptr<Parser> m_Parser;
    std::unique_ptr<Interpreter> m_Interpreter;
    NSLayoutConstraint *m_TopLayoutConstraint;
    nc::utility::NativeFSManager *m_NativeFSManager;
    const nc::utility::ActionsShortcutsManager *m_ActionsShortcutsManager;
    std::string m_InitalWD;
    std::string m_WindowTitle;
    std::string m_IconTitle;
    std::unique_ptr<ChildrenTracker> m_ChildrenTracker;
}

- (id)initWithFrame:(NSRect)frameRect
            nativeFSManager:(nc::utility::NativeFSManager &)_native_fs_man
    actionsShortcutsManager:(const nc::utility::ActionsShortcutsManager &)_actions_shortcuts_manager
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        __weak NCTermShellState *weak_self = self;
        m_NativeFSManager = &_native_fs_man;
        m_ActionsShortcutsManager = &_actions_shortcuts_manager;
        m_InitalWD = nc::base::CommonPaths::Home();

        m_TermScrollView = [[NCTermScrollView alloc] initWithFrame:self.bounds
                                                       attachToTop:true
                                                          settings:TerminalSettings()];
        m_TermScrollView.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_TermScrollView];
        const auto views = NSDictionaryOfVariableBindings(m_TermScrollView);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_TermScrollView]-(==0)-|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0@250)-[m_TermScrollView]-(==0)-|"
                                                                     options:0
                                                                     metrics:nil
                                                                       views:views]];

        m_Task = std::make_unique<ShellTask>();
        if( !GlobalConfig().GetBool(g_UseDefault) )
            if( GlobalConfig().Has(g_CustomPath) )
                m_Task->SetShellPath(GlobalConfig().GetString(g_CustomPath));
        auto task_ptr = m_Task.get();

        m_InputTranslator = std::make_unique<InputTranslatorImpl>();
        m_InputTranslator->SetOuput([task_ptr](std::span<const std::byte> _bytes) {
            task_ptr->WriteChildInput(std::string_view(reinterpret_cast<const char *>(_bytes.data()), _bytes.size()));
        });

        ParserImpl::Params parser_params;
        parser_params.error_log = [](std::string_view _error) { Log::Error("parsing error: {}", _error); };
        m_Parser = std::make_unique<ParserImpl>(parser_params);

        m_Interpreter = std::make_unique<InterpreterImpl>(m_TermScrollView.screen);
        m_Interpreter->SetOuput([=](std::span<const std::byte> _bytes) {
            task_ptr->WriteChildInput(std::string_view(reinterpret_cast<const char *>(_bytes.data()), _bytes.size()));
        });
        m_Interpreter->SetBell([] { NSBeep(); });
        m_Interpreter->SetTitle([weak_self](const std::string &_title, Interpreter::TitleKind _kind) {
            dispatch_to_main_queue([weak_self, _title, _kind] {
                if( NCTermShellState *const me = weak_self ) {
                    if( _kind == Interpreter::TitleKind::Icon )
                        me->m_IconTitle = _title;
                    if( _kind == Interpreter::TitleKind::Window )
                        me->m_WindowTitle = _title;
                    [me updateTitle];
                }
            });
        });
        m_Interpreter->SetInputTranslator(m_InputTranslator.get());
        m_Interpreter->SetShowCursorChanged([weak_self](bool _show) {
            NCTermShellState *const me = weak_self;
            me->m_TermScrollView.view.showCursor = _show;
        });
        m_Interpreter->SetCursorStyleChanged([weak_self](std::optional<CursorMode> _mode) {
            NCTermShellState *const me = weak_self;
            if( _mode )
                me->m_TermScrollView.view.cursorMode = *_mode;
            else
                me->m_TermScrollView.view.cursorMode = me->m_TermScrollView.view.settings->CursorMode();
        });
        m_Interpreter->SetRequstedMouseEventsChanged([weak_self](Interpreter::RequestedMouseEvents _events) {
            NCTermShellState *const me = weak_self;
            me->m_TermScrollView.view.mouseEvents = _events;
        });
        m_Interpreter->SetScreenResizeAllowed(false);

        [m_TermScrollView.view AttachToInputTranslator:m_InputTranslator.get()];
        m_TermScrollView.onScreenResized = [weak_self](int _sx, int _sy) {
            NCTermShellState *const me = weak_self;
            me->m_Interpreter->NotifyScreenResized();
            me->m_Task->ResizeWindow(_sx, _sy);
            [me updateTitle];
        };

        self.wantsLayer = true;

        [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self
                                                           selector:@selector(volumeWillUnmount:)
                                                               name:NSWorkspaceWillUnmountNotification
                                                             object:nil];
    }
    return self;
}

- (void)dealloc
{
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
}

- (BOOL)canDrawSubviewsIntoLayer
{
    return true;
}

- (BOOL)isOpaque
{
    return true;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // can't use updateLayer, as canDrawSubviewsIntoLayer=true, so use drawRect
    [CurrentTheme().TerminalOverlayColor() set];
    NSRectFill(dirtyRect);
}

- (NSView *)windowStateContentView
{
    return self;
}

- (NSToolbar *)windowStateToolbar
{
    return nil;
}

- (ShellTask &)task
{
    assert(m_Task);
    return *m_Task;
}

- (std::string)initialWD
{
    return m_InitalWD;
}

- (void)setInitialWD:(const std::string &)_wd
{
    if( !_wd.empty() )
        m_InitalWD = _wd;
}

- (void)windowStateDidBecomeAssigned
{
    m_TopLayoutConstraint = [NSLayoutConstraint constraintWithItem:m_TermScrollView
                                                         attribute:NSLayoutAttributeTop
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:self.window.contentLayoutGuide
                                                         attribute:NSLayoutAttributeTop
                                                        multiplier:1
                                                          constant:0];
    m_TopLayoutConstraint.active = true;
    [self layoutSubtreeIfNeeded];

    __weak NCTermShellState *weakself = self;
    m_Task->SetOnChildOutput([=](const void *_d, int _sz) {
        assert(_sz > 0);

        auto strongself = weakself;
        if( !strongself )
            return;

        const std::span<const std::byte> bytes{static_cast<const std::byte *>(_d), static_cast<size_t>(_sz)};
        [strongself dumpRawInputIfRequired:bytes];

        auto cmds = strongself->m_Parser->Parse(bytes);
        if( cmds.empty() )
            return;

        dispatch_to_main_queue([=, cmds = std::move(cmds)] {
            if( Log::Level() <= spdlog::level::debug )
                nc::term::input::LogCommands(cmds);

            if( auto lock = strongself->m_TermScrollView.screen.AcquireLock() )
                strongself->m_Interpreter->Interpret(cmds);
            [strongself->m_TermScrollView.view.fpsDrawer invalidate];
            [strongself->m_TermScrollView.view adjustSizes:false];
        });
    });

    m_Task->SetOnPwdPrompt([=]([[maybe_unused]] const char *_cwd, [[maybe_unused]] bool _changed) {
        if( auto strongself = weakself ) {
            strongself->m_IconTitle = "";
            strongself->m_WindowTitle = "";
            [strongself updateTitle];
        }
    });

    m_Task->SetOnStateChange([=](ShellTask::TaskState _new_state) {
        if( auto strongself = weakself )
            [strongself taskStateChanged:_new_state];
    });

    // need right CWD here
    if( m_Task->State() == ShellTask::TaskState::Inactive || m_Task->State() == ShellTask::TaskState::Dead ) {
        m_Task->ResizeWindow(m_TermScrollView.screen.Width(), m_TermScrollView.screen.Height());
        m_Task->Launch(m_InitalWD.c_str());
    }

    [self.window makeFirstResponder:m_TermScrollView.view];
    [self updateTitle];
    [m_TermScrollView tile];
    [m_TermScrollView.view scrollToBottom];
}

- (void)windowStateDidResign
{
    m_TopLayoutConstraint.active = false;
}

- (NSString *)buildTitle
{
    // NB! may be called from a background thread
    const auto sx = m_TermScrollView.screen.Width();
    const auto sy = m_TermScrollView.screen.Height();

    std::string title;

    if( !m_IconTitle.empty() || !m_WindowTitle.empty() ) {
        if( !m_IconTitle.empty() && !m_WindowTitle.empty() && m_IconTitle != m_WindowTitle ) {
            title = fmt::format("{} \u2015 {} \u2015 {}x{}", m_WindowTitle, m_IconTitle, sx, sy);
        }
        else if( !m_IconTitle.empty() ) {
            title = fmt::format("{} \u2015 {}x{}", m_IconTitle, sx, sy);
        }
        else if( !m_WindowTitle.empty() ) {
            title = fmt::format("{} \u2015 {}x{}", m_WindowTitle, sx, sy);
        }
    }
    else {
        auto children = m_Task->ChildrenList();
        if( children.empty() ) {
            title = fmt::format("{} \u2015 {}x{}", EnsureTrailingSlash(m_Task->CWD()), sx, sy);
        }
        else {
            title =
                fmt::format("{} \u2015 {} \u2015 {}x{}", EnsureTrailingSlash(m_Task->CWD()), children.back(), sx, sy);
        }
    }
    return [NSString stringWithUTF8StdString:title];
}

- (void)updateTitle
{
    NSString *new_title = [self buildTitle];
    dispatch_or_run_in_main_queue([=] { self.window.title = new_title; });
}

- (void)chDir:(const std::string &)_new_dir
{
    m_Task->ChDir(_new_dir.c_str());
}

- (void)execute:(const char *)_binary_name at:(const char *)_binary_dir
{
    [self execute:_binary_name at:_binary_dir parameters:nullptr];
}

- (void)execute:(const char *)_binary_name at:(const char *)_binary_dir parameters:(const char *)_params
{
    m_Task->Execute(_binary_name, _binary_dir, _params);
}

- (void)executeWithFullPath:(const std::filesystem::path &)_binary_path
               andArguments:(std::span<const std::string>)_params
{
    m_Task->ExecuteWithFullPath(_binary_path, _params);
}

- (bool)windowStateShouldClose:(NCMainWindowController *)sender
{
    if( m_Task->State() == ShellTask::TaskState::Dead || m_Task->State() == ShellTask::TaskState::Inactive ||
        m_Task->State() == ShellTask::TaskState::Shell )
        return true;

    auto children = m_Task->ChildrenList();
    if( children.empty() )
        return true;

    Alert *dialog = [[Alert alloc] init];
    dialog.messageText =
        NSLocalizedString(@"Do you want to close this window?", "Asking to close window with processes running");
    NSMutableString *cap = [NSMutableString new];
    [cap appendString:NSLocalizedString(@"Closing this window will terminate the running processes: ",
                                        "Informing when closing with running terminal processes")];
    for( int i = 0, e = static_cast<int>(children.size()); i != e; ++i ) {
        [cap appendString:[NSString stringWithUTF8String:children[i].c_str()]];
        if( i != static_cast<int>(children.size()) - 1 )
            [cap appendString:@", "];
    }
    [cap appendString:@"."];
    dialog.informativeText = cap;
    [dialog addButtonWithTitle:NSLocalizedString(@"Terminate and Close", "User confirmation on message box")];
    [dialog addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    [dialog beginSheetModalForWindow:sender.window
                   completionHandler:^(NSModalResponse result) {
                     if( result == NSAlertFirstButtonReturn )
                         [sender.window close];
                   }];

    return false;
}

- (bool)isAnythingRunning
{
    auto state = m_Task->State();
    return state == ShellTask::TaskState::ProgramExternal || state == ShellTask::TaskState::ProgramInternal;
}

- (void)terminate
{
    m_Task->Terminate();
}

- (std::string)cwd
{
    if( m_Task->State() == ShellTask::TaskState::Inactive || m_Task->State() == ShellTask::TaskState::Dead )
        return "";

    return m_Task->CWD();
}

- (IBAction)OnShowTerminal:(id) [[maybe_unused]] _sender
{
    [static_cast<NCMainWindowController *>(self.window.delegate) ResignAsWindowState:self];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    static const int show_terminal_tag = m_ActionsShortcutsManager->TagFromAction("menu.view.show_terminal").value();
    const long tag = item.tag;
    if( tag == show_terminal_tag ) {
        item.title = NSLocalizedString(@"Hide Terminal", "Menu item title for hiding terminal");
        return true;
    }
    return true;
}

- (void)volumeWillUnmount:(NSNotification *)notification
{
    // manually check if attached terminal is locking the volument is about to be unmounted.
    // in that case - change working directory so volume can be actually unmounted.
    if( NSString *path = notification.userInfo[@"NSDevicePath"] ) {
        auto state = self.task.State();
        if( state == ShellTask::TaskState::Shell ) {
            auto cwd_volume = m_NativeFSManager->VolumeFromPath(self.cwd);
            auto unmounting_volume = m_NativeFSManager->VolumeFromPath(path.fileSystemRepresentationSafe);
            if( cwd_volume == unmounting_volume )
                [self chDir:"/Volumes/"]; // TODO: need to do something more elegant
        }
    }
}

- (void)dumpRawInputIfRequired:(std::span<const std::byte>)_bytes
{
    dispatch_assert_background_queue();
    if( Log::Level() <= spdlog::level::trace ) {
        auto input = term::input::FormatRawInput(_bytes);
        dispatch_to_main_queue([input = std::move(input)] { Log::Trace("raw input: {}", input); });
    }
    //    std::cerr <<  term::input::FormatRawInput(_bytes) << std::endl;
}

- (void)taskStateChanged:(ShellTask::TaskState)_new_state
{
    // may be a background thread
    if( m_ChildrenTracker == nullptr || m_ChildrenTracker->pid() != m_Task->ShellPID() ) {
        if( m_Task->ShellPID() < 0 ) {
            m_ChildrenTracker.reset();
        }
        else {
            __weak NCTermShellState *weakself = self;
            auto cb = [weakself] {
                dispatch_to_main_queue([weakself] {
                    if( auto strongself = weakself )
                        [strongself updateTitle];
                });
            };
            m_ChildrenTracker = std::make_unique<ChildrenTracker>(m_Task->ShellPID(), cb);
        }
    }
}

@end

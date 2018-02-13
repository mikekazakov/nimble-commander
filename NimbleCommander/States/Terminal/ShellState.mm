// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ShellState.h"
#include <Habanero/CommonPaths.h>
#include <Utility/NativeFSManager.h>
#include <Utility/PathManip.h>
#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/States/MainWindowController.h>
#include <Term/ShellTask.h>
#include <Term/Screen.h>
#include <Term/Parser.h>
#include <Term/View.h>
#include <Term/ScrollView.h>
#include "SettingsAdaptor.h"

using namespace nc;
using namespace nc::term;

static const auto g_UseDefault = "terminal.useDefaultLoginShell";
static const auto g_CustomPath = "terminal.customShellPath";

@implementation NCTermShellState
{
    NCTermScrollView           *m_TermScrollView;
    unique_ptr<ShellTask>       m_Task;
    unique_ptr<Parser>          m_Parser;
    string                      m_InitalWD;
    NSLayoutConstraint         *m_TopLayoutConstraint;
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        m_InitalWD = CommonPaths::Home();
        
        m_TermScrollView = [[NCTermScrollView alloc] initWithFrame:self.bounds
                                                       attachToTop:true
                                                          settings:TerminalSettings()];
        m_TermScrollView.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_TermScrollView];
        const auto views = NSDictionaryOfVariableBindings(m_TermScrollView);
        [self addConstraints:
            [NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_TermScrollView]-(==0)-|"
                                                    options:0
                                                    metrics:nil
                                                    views:views]];
        [self addConstraints:
            [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0@250)-[m_TermScrollView]-(==0)-|"
                                                    options:0
                                                    metrics:nil
                                                    views:views]];

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
        self.wantsLayer = true;
        
        [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self
                                                           selector:@selector(volumeWillUnmount:)
                                                               name:NSWorkspaceWillUnmountNotification
                                                             object:nil];
    }
    return self;
}

- (void) dealloc
{
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
}

- (BOOL) canDrawSubviewsIntoLayer
{
    return true;
}

- (BOOL) isOpaque
{
    return true;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // can't use updateLayer, as canDrawSubviewsIntoLayer=true, so use drawRect
    [CurrentTheme().TerminalOverlayColor() set];
    NSRectFill(dirtyRect);
}

- (NSView*) windowStateContentView
{
    return self;
}

- (NSToolbar*) windowStateToolbar
{
    return nil;
}

- (ShellTask&) task
{
    assert(m_Task);
    return *m_Task;
}

- (string) initialWD
{
    return m_InitalWD;
}

- (void) setInitialWD:(const string&)_wd
{
    if( !_wd.empty() )
        m_InitalWD = _wd;
}

- (void) windowStateDidBecomeAssigned
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
    m_Task->SetOnChildOutput([=](const void* _d, int _sz){
        if( auto strongself = weakself ) {
            bool newtitle = false;
            if( auto lock = strongself->m_TermScrollView.screen.AcquireLock() ) {
                int flags = strongself->m_Parser->EatBytes((const unsigned char*)_d, _sz);
                if(flags & Parser::Result_ChangedTitle)
                    newtitle = true;
            }
            [strongself->m_TermScrollView.view.fpsDrawer invalidate];
            dispatch_to_main_queue( [=]{
                [strongself->m_TermScrollView.view adjustSizes:false];
                if(newtitle)
                    [strongself updateTitle];
            });
        }
    });
    
    m_Task->SetOnPwdPrompt([=](const char *_cwd, bool _changed){
        if( auto strongself = weakself ) {
            strongself->m_TermScrollView.screen.SetTitle("");
            [strongself updateTitle];
        }
    });
    
    
    // need right CWD here
    if( m_Task->State() == ShellTask::TaskState::Inactive ||
        m_Task->State() == ShellTask::TaskState::Dead ) {
        m_Task->ResizeWindow( m_TermScrollView.screen.Width(), m_TermScrollView.screen.Height() );
        m_Task->Launch( m_InitalWD.c_str() );
    }

    
    [self.window makeFirstResponder:m_TermScrollView.view];
    [self updateTitle];
    GA().PostScreenView("Terminal State");
}

- (void)windowStateDidResign
{
    m_TopLayoutConstraint.active = false;
}

- (void) updateTitle
{
    const auto lock = m_TermScrollView.screen.AcquireLock();
    const auto screen_title = m_TermScrollView.screen.Title();
    const auto title = [NSString stringWithUTF8StdString:screen_title.empty() ?
                        EnsureTrailingSlash(m_Task->CWD()) :
                        screen_title];
    dispatch_or_run_in_main_queue([=]{
        self.window.title = title;
    });
}

- (void) chDir:(const string&)_new_dir
{
    m_Task->ChDir(_new_dir.c_str());
}

- (void) execute:(const char*)_binary_name
              at:(const char*)_binary_dir
{
    [self execute:_binary_name at:_binary_dir parameters:nullptr];
}

- (void) execute:(const char*)_binary_name
              at:(const char*)_binary_dir
      parameters:(const char*)_params
{
    m_Task->Execute(_binary_name, _binary_dir, _params);
}

- (void) executeWithFullPath:(const char *)_path parameters:(const char*)_params
{
    m_Task->ExecuteWithFullPath(_path, _params);
}

- (bool)windowStateShouldClose:(NCMainWindowController*)sender
{    
    if(m_Task->State() == ShellTask::TaskState::Dead ||
       m_Task->State() == ShellTask::TaskState::Inactive ||
       m_Task->State() == ShellTask::TaskState::Shell)
        return true;
    
    auto children = m_Task->ChildrenList();
    if(children.empty())
        return true;

    Alert *dialog = [[Alert alloc] init];
    dialog.messageText = NSLocalizedString(@"Do you want to close this window?", "Asking to close window with processes running");
    NSMutableString *cap = [NSMutableString new];
    [cap appendString:NSLocalizedString(@"Closing this window will terminate the running processes: ", "Informing when closing with running terminal processes")];
    for( int i = 0, e = (int)children.size(); i != e; ++i ) {
        [cap appendString:[NSString stringWithUTF8String:children[i].c_str()]];
        if(i != (int)children.size() - 1)
            [cap appendString:@", "];
    }
    [cap appendString:@"."];
    dialog.informativeText = cap;
    [dialog addButtonWithTitle:NSLocalizedString(@"Terminate and Close", "User confirmation on message box")];
    [dialog addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    [dialog beginSheetModalForWindow:sender.window completionHandler:^(NSModalResponse result) {
        if (result == NSAlertFirstButtonReturn)
            [sender.window close];
    }];
    
    return false;
}

- (bool) isAnythingRunning
{
    auto state = m_Task->State();
    return state == ShellTask::TaskState::ProgramExternal ||
           state == ShellTask::TaskState::ProgramInternal;
}

- (void) terminate
{
    m_Task->Terminate();
}

- (string)cwd
{
    if(m_Task->State() == ShellTask::TaskState::Inactive ||
       m_Task->State() == ShellTask::TaskState::Dead)
        return "";
    
    return m_Task->CWD();
}

- (IBAction)OnShowTerminal:(id)sender
{
    [(NCMainWindowController*)self.window.delegate ResignAsWindowState:self];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto tag = item.tag;
    IF_MENU_TAG("menu.view.show_terminal") {
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
            auto cwd_volume = NativeFSManager::Instance().VolumeFromPath( self.cwd );
            auto unmounting_volume = NativeFSManager::Instance().VolumeFromPath(
                path.fileSystemRepresentationSafe );
            if( cwd_volume == unmounting_volume )
                [self chDir:"/Volumes/"]; // TODO: need to do something more elegant
        }
    }
}

@end

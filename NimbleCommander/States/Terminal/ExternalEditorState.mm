// Copyright (C) 2014-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExternalEditorState.h"
#include <Utility/FontCache.h>
#include "../../../NimbleCommander/States/MainWindowController.h"
#include <Term/SingleTask.h>
#include <Term/Screen.h>
#include <Term/Parser.h>
#include <Term/View.h>
#include <Term/ScrollView.h>
#include "SettingsAdaptor.h"
#include <Habanero/dispatch_cpp.h>
#include <Utility/StringExtras.h>

using namespace nc;
using namespace nc::term;

@implementation NCTermExternalEditorState
{
    std::unique_ptr<SingleTask> m_Task;
    std::unique_ptr<Parser>     m_Parser;
    NCTermScrollView           *m_TermScrollView;
    boost::filesystem::path     m_BinaryPath;
    std::string                 m_Params;
    std::string                 m_FileTitle;
    NSLayoutConstraint         *m_TopLayoutConstraint;
}

- (id)initWithFrameAndParams:(NSRect)frameRect
                      binary:(const boost::filesystem::path&)_binary_path
                      params:(const std::string&)_params
                   fileTitle:(const std::string&)_file_title
{
    self = [super initWithFrame:frameRect];
    if (self) {
        m_BinaryPath = _binary_path;
        m_Params = _params;
        m_FileTitle = _file_title;

        m_TermScrollView = [[NCTermScrollView alloc] initWithFrame:self.bounds
                                                       attachToTop:true
                                                          settings:term::TerminalSettings()];
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
        
        __weak NCTermExternalEditorState *weakself = self;
        
        m_Task = std::make_unique<SingleTask>();
        auto task_raw_ptr = m_Task.get();
        m_Parser = std::make_unique<Parser>(m_TermScrollView.screen,
                                       [=](const void* _d, int _sz){
                                           task_raw_ptr->WriteChildInput(_d, _sz);
                                       });

        m_Parser->SetTaskScreenResize([=](int sx, int sy) {
            task_raw_ptr->ResizeWindow(sx, sy);
        });
        
        [m_TermScrollView.view AttachToParser:m_Parser.get()];

        m_Task->SetOnChildOutput([=](const void* _d, int _sz){
            if( auto strongself = weakself ) {
                bool newtitle = false;
                if( auto lock = strongself->m_TermScrollView.screen.AcquireLock() ) {
                    int flags = strongself->m_Parser->EatBytes((const unsigned char*)_d, _sz);
                    if(flags & Parser::Result_ChangedTitle)
                        newtitle = true;
                    strongself->m_Parser->Flush();
                }
                [strongself->m_TermScrollView.view.fpsDrawer invalidate];
                
                dispatch_to_main_queue( [=]{
                    [strongself->m_TermScrollView.view adjustSizes:false]; // !!!!! REFACTOR  !!!
                    if(newtitle)
                        [strongself updateTitle];
                });
            }
        });
        m_Task->SetOnChildDied([weakself]{
            dispatch_to_main_queue( [=]{
                if( auto strongself = weakself )
                    [(NCMainWindowController*)strongself.window.delegate ResignAsWindowState:strongself];
            });
        });
    }
    return self;
}

- (NSView*) windowStateContentView
{
    return self;
}

- (NSToolbar*)windowStateToolbar
{
    return nil;
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

    m_Task->Launch(m_BinaryPath.c_str(),
                   m_Params.c_str(),
                   m_TermScrollView.screen.Width(),
                   m_TermScrollView.screen.Height());
    
    [self.window makeFirstResponder:m_TermScrollView.view];
    [self updateTitle];
}

- (void)windowStateDidResign
{
    m_TopLayoutConstraint.active = false;
}

- (void) updateTitle
{
    auto lock = m_TermScrollView.screen.AcquireLock();
    NSString *title = [NSString stringWithUTF8StdString:m_TermScrollView.screen.Title()];
    
    if(title.length == 0)
        title = [NSString stringWithFormat:@"%@ - %@",
                 [NSString stringWithUTF8StdString:m_Task->TaskBinaryName()],
                 [NSString stringWithUTF8StdString:m_FileTitle]];
    
    dispatch_or_run_in_main_queue([=]{
        self.window.title = title;
    });
}

- (bool)windowStateShouldClose:(NCMainWindowController*)[[maybe_unused]]_sender
{
    return false;
}

@end

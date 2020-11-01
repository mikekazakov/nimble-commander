// Copyright (C) 2014-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExternalEditorState.h"
#include "../../../NimbleCommander/States/MainWindowController.h"
#include <Term/SingleTask.h>
#include <Term/Screen.h>
#include <Term/InterpreterImpl.h>
#include <Term/Parser.h>
#include <Term/Parser2Impl.h>
#include <Term/View.h>
#include <Term/ScrollView.h>
#include <Term/InputTranslatorImpl.h>
#include "SettingsAdaptor.h"
#include <Habanero/dispatch_cpp.h>
#include <Utility/StringExtras.h>

using namespace nc;
using namespace nc::term;

@implementation NCTermExternalEditorState
{
    std::unique_ptr<SingleTask> m_Task;
//    std::unique_ptr<Parser>     m_Parser;
    std::unique_ptr<Parser2>            m_Parser;
    std::unique_ptr<InputTranslator>    m_InputTranslator;
    std::unique_ptr<Interpreter>        m_Interpreter;
    NCTermScrollView           *m_TermScrollView;
    boost::filesystem::path     m_BinaryPath;
    std::string                 m_Params;
    std::string                 m_FileTitle;
    NSLayoutConstraint         *m_TopLayoutConstraint;
    std::string                 m_Title;
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
        
        __weak NCTermExternalEditorState *weak_self = self;
        
        m_Task = std::make_unique<SingleTask>();
        auto task_raw_ptr = m_Task.get();
//        m_Parser = std::make_unique<Parser>(m_TermScrollView.screen,
//                                       [=](const void* _d, int _sz){
//                                           task_raw_ptr->WriteChildInput(_d, _sz);
//                                       });
//
//        m_Parser->SetTaskScreenResize([=](int sx, int sy) {
//            task_raw_ptr->ResizeWindow(sx, sy);
//        });
                
        m_InputTranslator = std::make_unique<InputTranslatorImpl>();
        m_InputTranslator->SetOuput([=]( std::span<const std::byte> _bytes  ){
            task_raw_ptr->WriteChildInput( (const void*)_bytes.data(), _bytes.size() );
        });
        
        Parser2Impl::Params parser_params;
        parser_params.error_log = [](std::string_view _error){
            std::cerr << _error << std::endl;
        };
        m_Parser = std::make_unique<Parser2Impl>(parser_params);
                
        m_Interpreter = std::make_unique<InterpreterImpl>(m_TermScrollView.screen);
        m_Interpreter->SetOuput([=](std::span<const std::byte> _bytes){
            task_raw_ptr->WriteChildInput( (const void*)_bytes.data(), _bytes.size() );
        });
        m_Interpreter->SetBell([]{
            NSBeep();
        });
        m_Interpreter->SetTitle([weak_self](const std::string &_title, bool, bool){
            dispatch_to_main_queue( [weak_self, _title]{
                NCTermExternalEditorState *me = weak_self;
                me->m_Title = _title;
                [me updateTitle];
            });
        });
        m_Interpreter->SetInputTranslator( m_InputTranslator.get() );
        
        [m_TermScrollView.view AttachToInputTranslator:m_InputTranslator.get()];
        m_TermScrollView.onScreenResized = [weak_self](int _sx, int _sy) {
            NCTermExternalEditorState *me = weak_self;
            me->m_Interpreter->NotifyScreenResized();
            me->m_Task->ResizeWindow(_sx, _sy);
        };

        m_Task->SetOnChildOutput([=](const void *_d, int _sz) {
            if( auto strongself = weak_self ) {
                auto cmds = strongself->m_Parser->Parse({(const std::byte *)_d, (size_t)_sz});
                if( cmds.empty() )
                    return;
                dispatch_to_main_queue([=] {
                    if( auto lock = strongself->m_TermScrollView.screen.AcquireLock() )
                        strongself->m_Interpreter->Interpret(cmds);
                    [strongself->m_TermScrollView.view.fpsDrawer invalidate];
                    [strongself->m_TermScrollView.view adjustSizes:false];
                });
            }
        });
        m_Task->SetOnChildDied([weak_self]{
            dispatch_to_main_queue( [=]{
                if( auto strongself = weak_self )
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
//    auto lock = m_TermScrollView.screen.AcquireLock();
////    NSString *title = [NSString stringWithUTF8StdString:m_TermScrollView.screen.Title()];
//    NSString *title = @"";
//
//    if(title.length == 0)
//        title = [NSString stringWithFormat:@"%@ - %@",
//                 [NSString stringWithUTF8StdString:m_Task->TaskBinaryName()],
//                 [NSString stringWithUTF8StdString:m_FileTitle]];
//
//    dispatch_or_run_in_main_queue([=]{
//        self.window.title = title;
//    });
    const auto &screen_title = m_Title;
    const auto title = [NSString stringWithUTF8StdString:screen_title.empty() ?
                        ( m_Task->TaskBinaryName() + " - " + m_FileTitle ) :
                        screen_title];
    dispatch_or_run_in_main_queue([=]{
        self.window.title = title;
    });
}

- (bool)windowStateShouldClose:(NCMainWindowController*)[[maybe_unused]]_sender
{
    return false;
}

@end

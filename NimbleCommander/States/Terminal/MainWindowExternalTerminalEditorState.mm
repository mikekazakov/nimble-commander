//
//  MainWindowExternalTerminalEditorState.m
//  Files
//
//  Created by Michael G. Kazakov on 04.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <Utility/FontCache.h>
#include "../../../NimbleCommander/States/MainWindowController.h"
#include "TermSingleTask.h"
#include "TermScreen.h"
#include "TermParser.h"
#include "TermView.h"
#include "TermScrollView.h"
#include "MainWindowExternalTerminalEditorState.h"

@implementation MainWindowExternalTerminalEditorState
{
    unique_ptr<TermSingleTask>  m_Task;
    unique_ptr<TermParser>      m_Parser;
    TermScrollView             *m_TermScrollView;
    path                        m_BinaryPath;
    string                      m_Params;
    string                      m_FileTitle;
    NSLayoutConstraint         *m_TopLayoutConstraint;
}

- (id)initWithFrameAndParams:(NSRect)frameRect
                      binary:(const path&)_binary_path
                      params:(const string&)_params
                   fileTitle:(const string&)_file_title
{
    self = [super initWithFrame:frameRect];
    if (self) {
        m_BinaryPath = _binary_path;
        m_Params = _params;
        m_FileTitle = _file_title;

        m_TermScrollView = [[TermScrollView alloc] initWithFrame:self.bounds attachToTop:true];
        m_TermScrollView.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_TermScrollView];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_TermScrollView]-(==0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(m_TermScrollView)]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0@250)-[m_TermScrollView]-(==0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(m_TermScrollView)]];
        
        
        
        __weak MainWindowExternalTerminalEditorState *weakself = self;
        
        m_Task = make_unique<TermSingleTask>();
        auto task_raw_ptr = m_Task.get();
        m_Parser = make_unique<TermParser>(m_TermScrollView.screen,
                                           [=](const void* _d, int _sz){
                                               task_raw_ptr->WriteChildInput(_d, _sz);
                                           });

        m_Parser->SetTaskScreenResize([=](int sx, int sy) {
            task_raw_ptr->ResizeWindow(sx, sy);
        });
        
        [m_TermScrollView.view AttachToParser:m_Parser.get()];

        m_Task->SetOnChildOutput([=](const void* _d, int _sz){
            if(MainWindowExternalTerminalEditorState *strongself = weakself) {
                bool newtitle = false;
                if( auto lock = strongself->m_TermScrollView.screen.AcquireLock() ) {
                    int flags = strongself->m_Parser->EatBytes((const unsigned char*)_d, _sz);
                    if(flags & TermParser::Result_ChangedTitle)
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
        m_Task->SetOnChildDied(^{
            dispatch_to_main_queue( [=]{
                if(MainWindowExternalTerminalEditorState *strongself = weakself)
                    [(MainWindowController*)strongself.window.delegate ResignAsWindowState:strongself];
            });
        });
    }
    return self;
}

- (NSView*) windowContentView
{
    return self;
}

- (NSToolbar*)toolbar
{
    return nil;
}

- (void) Assigned
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

    m_Task->Launch(m_BinaryPath.c_str(), m_Params.c_str(), m_TermScrollView.screen.Width(), m_TermScrollView.screen.Height());
    
    [self.window makeFirstResponder:m_TermScrollView.view];
    [self updateTitle];
}

- (void)Resigned
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

- (bool)WindowShouldClose:(MainWindowController*)sender
{
    return false;
}

@end

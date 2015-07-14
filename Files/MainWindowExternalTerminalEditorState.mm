//
//  MainWindowExternalTerminalEditorState.m
//  Files
//
//  Created by Michael G. Kazakov on 04.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "TermSingleTask.h"
#import "TermScreen.h"
#import "TermParser.h"
#import "TermView.h"
#import "FontCache.h"
#import "Common.h"
#import "MainWindowController.h"
#import "MainWindowExternalTerminalEditorState.h"

#import "TermScrollView.h"

@implementation MainWindowExternalTerminalEditorState
{
    unique_ptr<TermSingleTask>  m_Task;
    unique_ptr<TermParser>      m_Parser;
    TermScrollView             *m_TermScrollView;
    path                        m_BinaryPath;
    string                      m_Params;
    path                        m_FilePath;
}

- (id)initWithFrameAndParams:(NSRect)frameRect
                      binary:(const path&)_binary_path
                      params:(const string&)_params
                        file:(const path&)_file_path
{
    assert(_file_path.is_absolute());
    
    self = [super initWithFrame:frameRect];
    if (self) {
        m_BinaryPath = _binary_path;
        m_Params = _params;
        m_FilePath = _file_path;

        m_TermScrollView = [[TermScrollView alloc] initWithFrame:self.bounds];
        m_TermScrollView.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_TermScrollView];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_TermScrollView]-(==0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(m_TermScrollView)]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_TermScrollView]-(==0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(m_TermScrollView)]];
        
        
        
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
                strongself->m_TermScrollView.screen.Lock();

                for(int i = 0; i < _sz; ++i) {
                    int flags = 0;
                    strongself->m_Parser->EatByte(((const char*)_d)[i], flags);
                    if(flags & TermParser::Result_ChangedTitle)
                        newtitle = true;
                }
                
                strongself->m_Parser->Flush();
                strongself->m_TermScrollView.screen.Unlock();
                [strongself->m_TermScrollView.view.FPSDrawer invalidate];
                
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
    m_Task->Launch(m_BinaryPath.c_str(), m_Params.c_str(), m_TermScrollView.screen.Width(), m_TermScrollView.screen.Height());
    
    [self.window makeFirstResponder:m_TermScrollView.view];
    [self updateTitle];
}

- (void) updateTitle
{
    m_TermScrollView.screen.Lock();
    NSString *title = [NSString stringWithUTF8StdString:m_TermScrollView.screen.Title()];
    m_TermScrollView.screen.Unlock();
    
    if(title.length == 0)
        title = [NSString stringWithFormat:@"%@ - %@",
                 [NSString stringWithUTF8StdString:m_Task->TaskBinaryName()],
                 [NSString stringWithUTF8StdString:m_FilePath.filename().native()]];
    
    dispatch_or_run_in_main_queue([=]{
        self.window.title = title;
    });
}

- (bool)WindowShouldClose:(MainWindowController*)sender
{
    return false;
}

@end

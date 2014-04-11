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

static const char *FileNameFromFilePath(const string &_fn)
{
    auto i = _fn.find_last_of('/');
    if(i == string::npos)
        return "";
    return _fn.c_str() + i + 1;
}

@implementation MainWindowExternalTerminalEditorState
{
    unique_ptr<TermSingleTask>  m_Task;
    unique_ptr<TermScreen>      m_Screen;
    unique_ptr<TermParser>      m_Parser;
    TermView                   *m_View;
    NSScrollView               *m_ScrollView;
    string                      m_BinaryPath;
    string                      m_Params;
    string                      m_FilePath;
}

- (id)initWithFrameAndParams:(NSRect)frameRect
                      binary:(const string&)_binary_path
                      params:(const string&)_params
                        file:(const string&)_file_path
{
    self = [super initWithFrame:frameRect];
    if (self) {
        m_BinaryPath = _binary_path;
        m_Params = _params;
        m_FilePath = _file_path;
        
        m_ScrollView = [[NSScrollView alloc] initWithFrame:self.bounds];
        m_ScrollView.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_ScrollView];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_ScrollView]-(==0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(m_ScrollView)]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_ScrollView]-(==0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(m_ScrollView)]];
        
        m_View = [[TermView alloc] initWithFrame:self.frame];
        m_ScrollView.documentView = m_View;
        m_ScrollView.hasVerticalScroller = true;
        m_ScrollView.borderType = NSNoBorder;
        m_ScrollView.verticalScrollElasticity = NSScrollElasticityNone;
        m_ScrollView.scrollsDynamically = true;
        m_ScrollView.contentView.copiesOnScroll = false;
        m_ScrollView.contentView.canDrawConcurrently = false;
        m_ScrollView.contentView.drawsBackground = false;
        
        __weak MainWindowExternalTerminalEditorState *weakself = self;
        
        m_Task = make_unique<TermSingleTask>();
        auto task_raw_ptr = m_Task.get();
        m_Screen = make_unique<TermScreen>(floor(frameRect.size.width / [m_View FontCache]->Width()),
                                           floor(frameRect.size.height / [m_View FontCache]->Height()));
        m_Parser = make_unique<TermParser>(m_Screen.get(),
                                           ^(const void* _d, int _sz){
                                                task_raw_ptr->WriteChildInput(_d, _sz);
                                           });
        [m_View AttachToScreen:m_Screen.get()];
        [m_View AttachToParser:m_Parser.get()];

        m_Task->SetOnChildOutput(^(const void* _d, int _sz){
            if(MainWindowExternalTerminalEditorState *strongself = weakself)
            {
                bool newtitle = false;
                strongself->m_Screen->Lock();
                for(int i = 0; i < _sz; ++i)
                {
                    int flags = 0;
                    
                    strongself->m_Parser->EatByte(((const char*)_d)[i], flags);
                    
                    if(flags & TermParser::Result_ChangedTitle)
                        newtitle = true;
                }
                
                strongself->m_Parser->Flush();
                strongself->m_Screen->Unlock();
                
                //            tmb.Reset("Parsed in: ");
                dispatch_to_main_queue( ^{
                    [strongself->m_View adjustSizes:false];
                    [strongself->m_View setNeedsDisplay:true];
                    if(newtitle)
                        [strongself updateTitle];
                });
            }
        });
        m_Task->SetOnChildDied(^{
            dispatch_to_main_queue( ^{
                if(MainWindowExternalTerminalEditorState *strongself = weakself)
                    [(MainWindowController*)strongself.window.delegate ResignAsWindowState:strongself];
            });
        });

        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];

    }
    return self;
}

- (void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (NSView*) ContentView
{
    return self;
}

- (void) Assigned
{
    m_Task->Launch(m_BinaryPath.c_str(), m_Params.c_str(), m_Screen->Width(), m_Screen->Height());
    [self.window makeFirstResponder:m_View];
    [self updateTitle];
}

- (void)frameDidChange
{
    if(self.frame.size.width != m_View.frame.size.width)
    {
        NSRect dr = m_View.frame;
        dr.size.width = self.frame.size.width;
        [m_View setFrame:dr];
    }
    
    int sy = floor(self.frame.size.height / [m_View FontCache]->Height());
    int sx = floor(m_View.frame.size.width / [m_View FontCache]->Width());
    
    m_Screen->ResizeScreen(sx, sy);
    m_Task->ResizeWindow(sx, sy);
    m_Parser->Resized();
    
    [m_View adjustSizes:true];
}


- (void) updateTitle
{
    NSString *title = nil;
    
    m_Screen->Lock();
    if(strlen(m_Screen->Title()) > 0)
        title = [NSString stringWithUTF8String:m_Screen->Title()];
    m_Screen->Unlock();
    
    if(title == nil)
        title = [NSString stringWithFormat:@"%@ - %@",
                 [NSString stringWithUTF8String:m_Task->TaskBinaryName()],
                 [NSString stringWithUTF8String:FileNameFromFilePath(m_FilePath)]];
    
    self.window.title = title;
}

@end

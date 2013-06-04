//
//  MainWindowBigFileViewState.m
//  Files
//
//  Created by Michael G. Kazakov on 04.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowBigFileViewState.h"
#import "BigFileView.h"
#import "FileWindow.h"
#import "MainWindowController.h"

@implementation MainWindowBigFileViewState
{
    FileWindow  *m_FileWindow;
    BigFileView *m_View;
    
    
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self)
    {
        [self CreateView];
    }
    return self;
}

- (void) dealloc
{
    if(m_FileWindow != 0)
    {
        if(m_FileWindow->FileOpened())
            m_FileWindow->CloseFile();
        delete m_FileWindow;
        m_FileWindow = 0;
    }
    
    
}

- (NSView*) ContentView
{
    return self;
}

- (void) Assigned
{
    
    
}

- (void) Resigned
{
    
    
}

- (void)cancelOperation:(id)sender
{
    [(MainWindowController*)[[self window] delegate] ResignAsWindowState:self];
}

- (bool) OpenFile: (const char*) _fn
{    
    FileWindow *fw = new FileWindow;
    if(fw->OpenFile(_fn) == 0)
    {
        if(m_FileWindow != 0)
        {
            if(m_FileWindow->FileOpened())
                m_FileWindow->CloseFile();
            delete m_FileWindow;
            m_FileWindow = 0;
        }
        
        m_FileWindow = fw;
        [m_View SetFile:m_FileWindow];
        
        return true;
    }
    else
    {
        delete fw;
        return false;
    }
}

- (void) CreateView
{
    m_View = [[BigFileView alloc] initWithFrame:self.frame];
    [m_View setTranslatesAutoresizingMaskIntoConstraints:NO];    
    [self addSubview:m_View];
    
    NSDictionary *views = NSDictionaryOfVariableBindings(m_View);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(<=1)-[m_View]-(<=1)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(<=1)-[m_View]-(<=1)-|" options:0 metrics:nil views:views]];
}

@end

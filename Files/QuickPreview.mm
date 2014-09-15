//
//  QuickPreview.m
//  Files
//
//  Created by Pavel Dogurevich on 26.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/types.h>
#import <sys/stat.h>
#import <Quartz/Quartz.h>
#import "QuickPreview.h"
#import "Common.h"
#import "TemporaryNativeFileStorage.h"

static const uint64_t g_MaxFileSizeForVFSQL = 64*1024*1024; // 64mb
static const nanoseconds g_Delay = 100ms;

@implementation QuickLookView
{
    string              m_OrigPath;
    volatile bool       m_Closed;
    atomic<uint64_t>    m_CurrentPreviewTicket;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect style:QLPreviewViewStyleNormal];
    if (self) {
        m_Closed = false;
        m_CurrentPreviewTicket = 0;
        self.shouldCloseWithWindow = false;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(frameDidChange)
                                                     name:NSViewFrameDidChangeNotification
                                                   object:self];
    }
    return self;
}

- (BOOL) acceptsFirstResponder
{
    return false;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)close
{
    [super close];
    m_Closed = true;
}

- (void)viewDidMoveToSuperview
{
    if(self.superview == nil)
        [self close];
}

- (void) doPreviewItemNative:(const string&)_path
{
    self.previewItem = [NSURL fileURLWithPath:[NSString stringWithUTF8String:_path.c_str()]];
}

- (void) doPreviewItemVFS:(const string&)_path vfs:(const VFSHostPtr&)_host ticket:(uint64_t)_ticket
{
    if(_host->IsDirectory(_path.c_str(), 0, 0))
    {
        dispatch_to_main_queue( ^{ self.previewItem = nil; });
        return;
    }
    VFSStat st;
    if(_host->Stat(_path.c_str(), st, 0, 0) < 0)
    {
        dispatch_to_main_queue( ^{ self.previewItem = nil; });
        return;
    }
    if(st.size > g_MaxFileSizeForVFSQL)
    {
        dispatch_to_main_queue( ^{ self.previewItem = nil; });
        return;
    }
    
    char tmp[MAXPATHLEN];
    if(!TemporaryNativeFileStorage::Instance().CopySingleFile(_path.c_str(), _host, tmp))
        return;
    NSString *fn = [NSString stringWithUTF8String:tmp];
    if(!m_Closed && _ticket == m_CurrentPreviewTicket)
        dispatch_to_main_queue( ^{
            if(!m_Closed)
                self.previewItem = [NSURL fileURLWithPath:fn];
        });
}

- (void)PreviewItem:(const string&)_path vfs:(const VFSHostPtr&)_host
{
    // may cause collisions of same filenames on different vfs, nevermind for now
    assert(!m_Closed);
    if(m_OrigPath == _path) return;
    
    m_OrigPath = _path;
    string path = _path;
    uint64_t ticket = ++m_CurrentPreviewTicket;
  
    if(_host->IsNativeFS())
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, g_Delay.count()), dispatch_get_main_queue(), ^{
            if(ticket != m_CurrentPreviewTicket)
                return;
            [self doPreviewItemNative:path];
        });
    else {
        VFSHostPtr host = _host;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, g_Delay.count()), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if(ticket != m_CurrentPreviewTicket)
                return;
            [self doPreviewItemVFS:path vfs:host ticket:ticket];
        });
    }
}

- (void)frameDidChange
{
    NSView *subview = self.subviews[0];
    [subview setFrameSize:self.frame.size];
}

@end

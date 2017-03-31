//
//  QuickPreview.m
//  Files
//
//  Created by Pavel Dogurevich on 26.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Quartz/Quartz.h>
#include "QuickPreview.h"
#include <NimbleCommander/Core/TemporaryNativeFileStorage.h>

static const uint64_t g_MaxFileSizeForVFSQL = 64*1024*1024; // 64mb
static const nanoseconds g_Delay = 100ms;

@interface QuickLookWrapper : QLPreviewView

- (void)PreviewItem:(const string&)_path vfs:(const VFSHostPtr&)_host;

@end

@implementation QuickLookWrapper
{
    string              m_OrigPath;
    atomic_bool         m_Closed;
    atomic_ullong       m_CurrentPreviewTicket;
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
    NSString *fn = [NSString stringWithUTF8StdString:_path];
    if(!fn)
        return;
    
    self.previewItem = [NSURL fileURLWithPath:fn];
}

- (void) doPreviewItemVFS:(const string&)_path vfs:(const VFSHostPtr&)_host ticket:(uint64_t)_ticket
{
    static auto &tnfs = TemporaryNativeFileStorage::Instance();
    bool dir = _host->IsDirectory(_path.c_str(), 0, 0);
    
    if( !dir ) {
        VFSStat st;
        if(_host->Stat(_path.c_str(), st, 0, 0) < 0) {
            dispatch_to_main_queue( [=]{ self.previewItem = nil; });
            return;
        }
        if(st.size > g_MaxFileSizeForVFSQL) {
            dispatch_to_main_queue( [=]{ self.previewItem = nil; });
            return;
        }
        
        if( auto tmp = tnfs.CopySingleFile(_path, _host) ) {
            NSString *fn = [NSString stringWithUTF8StdString:*tmp];
            if( !m_Closed && fn && _ticket == m_CurrentPreviewTicket )
                dispatch_to_main_queue( [=]{
                    if(!m_Closed)
                        self.previewItem = [NSURL fileURLWithPath:fn];
                });
        }
    }
    else {
        // basic check that directory looks like a bundle
        if(!path(_path).has_extension() ||
           path(_path).filename() == path(_path).extension() ) {
            if(!m_Closed)
                dispatch_to_main_queue( [=]{ self.previewItem = nil; });
            return;
        }
        
        string tmp;
        if(!tnfs.CopyDirectory(_path, _host, g_MaxFileSizeForVFSQL, nullptr, tmp))
            return;
        NSString *fn = [NSString stringWithUTF8StdString:tmp];
        if(!m_Closed && fn &&_ticket == m_CurrentPreviewTicket)
            dispatch_to_main_queue( [=]{
                if(!m_Closed)
                    self.previewItem = [NSURL fileURLWithPath:fn];
            });
    }
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
        dispatch_to_main_queue_after(g_Delay, [=]{
            if(ticket != m_CurrentPreviewTicket || m_Closed)
                return;
            [self doPreviewItemNative:path];
        });
    else {
        VFSHostPtr host = _host;
        dispatch_after(g_Delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), [=]{
            if(ticket == m_CurrentPreviewTicket)
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

@implementation QuickLookView
{
    QuickLookWrapper *m_QL;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        m_QL = [[QuickLookWrapper alloc] initWithFrame:self.frame];
        m_QL.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_QL];

        NSDictionary *views = NSDictionaryOfVariableBindings(m_QL);
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_QL]-(==0)-|" options:0 metrics:nil views:views]];
        [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_QL]-(==0)-|" options:0 metrics:nil views:views]];
    }
    return self;
}

- (void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)PreviewItem:(const string&)_path vfs:(const VFSHostPtr&)_host
{
    [m_QL PreviewItem:_path vfs:_host];
}

- (BOOL) acceptsFirstResponder
{
    return false;
}

- (BOOL) isOpaque
{
    return true;
}

- (void)drawRect:(NSRect)dirtyRect
{
    if(self.window.isKeyWindow) {
        CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;        
        static CGColorRef c = CGColorCreateGenericGray(244.0 / 255.0, 1.0);
        CGContextSetFillColorWithColor(context, c);
        CGRect rc = NSRectToCGRect(dirtyRect);
        CGContextFillRect(context, rc);
    }
    else {
        NSDrawWindowBackground(dirtyRect);
    }
}

- (void)viewWillMoveToWindow:(NSWindow *)_wnd
{
    if(!_wnd)
        return;
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(windowKeyChanged)
                                               name:NSWindowDidBecomeKeyNotification
                                             object:_wnd];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(windowKeyChanged)
                                               name:NSWindowDidResignKeyNotification
                                             object:_wnd];
}

- (void) windowKeyChanged
{
    self.needsDisplay = true;
}

@end

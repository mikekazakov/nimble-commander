// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "QuickLookPanel.h"
#include <Quartz/Quartz.h>
#include "../MainWindowFilePanelState.h"
#include "QuickLookVFSBridge.h"
#include <Habanero/dispatch_cpp.h>
#include <Utility/StringExtras.h>

static const std::chrono::nanoseconds g_Delay = std::chrono::milliseconds{100};

@implementation NCPanelQLPanelAdaptor
{
    std::string     m_CurrentPath;
    VFSHostWeakPtr  m_CurrentHost;
    std::atomic_ullong m_CurrentTicket;
    NSURL          *m_URL;
    __weak id       m_Owner;
    nc::panel::QuickLookVFSBridge *m_VFSBridge;
}

- (instancetype) initWithBridge:(nc::panel::QuickLookVFSBridge&)_vfs_bridge
{
    if( self = [super init] ) {
        m_CurrentTicket = 0;
        m_VFSBridge = &_vfs_bridge;
    }
    return self;
}

- (instancetype)init
{
    assert(0);
    return nil;
}

- (void)previewVFSItem:(const VFSPath&)_path forPanel:(PanelController*)[[maybe_unused]]_panel
{
    dispatch_assert_main_queue();
    
    if( !_path.Host() || _path.Path().empty() )
        return;
    
    if( _path.Path() == m_CurrentPath &&
        _path.Host() == m_CurrentHost.lock() )
        return;
    
    m_CurrentPath = _path.Path();
    m_CurrentHost = _path.Host();
    ++m_CurrentTicket;
    
    if( _path.Host()->IsNativeFS() )
        [self doNativePreview:_path.Path()];
    else
        [self doVFSPreview:_path.Path() host:_path.Host() ticket:m_CurrentTicket];
}

- (void)doNativePreview:(const std::string&)_path
{
    if( const auto path = [NSString stringWithUTF8StdString:_path] )
        [self setPreviewURL:[NSURL fileURLWithPath:path]];
}

- (void)doVFSPreview:(const std::string&)_path
                host:(const VFSHostPtr&)_host
              ticket:(uint64_t)_ticket
{
    auto refresh = [=]{
        if( _ticket != m_CurrentTicket )
            return;
        
        const auto url = m_VFSBridge->FetchItem(_path, *_host);
        
        if( _ticket != m_CurrentTicket )
            return;
        
        dispatch_to_main_queue([=]{
            if( _ticket != m_CurrentTicket )
                return;
            [self setPreviewURL:url];
        });
    };
    
    dispatch_after(g_Delay,
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                   std::move(refresh)
                   );
}

- (bool)registerExistingQLPreviewPanelFor:(id)_controller
{
    if( QLPreviewPanel.sharedPreviewPanelExists == false )
        return false;
    auto ql_panel = QLPreviewPanel.sharedPreviewPanel;
    
    if( ql_panel.currentController != _controller )
        return false;
    
    m_Owner = _controller;
    ql_panel.dataSource = self;
    ql_panel.delegate = self;
    return true;
}

- (bool)unregisterExistingQLPreviewPanelFor:(id)_controller
{
    if( _controller != m_Owner )
        return false;
    
    m_Owner = nil;
    m_CurrentPath = "";
    m_CurrentHost.reset();
    [self setPreviewURL:nil];
    
    return true;
}

- (__weak id)owner
{
    return m_Owner;
}

- (nc::panel::QuickLookVFSBridge&)bridge
{
    return *m_VFSBridge;
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)[[maybe_unused]]_panel
{
    return m_URL ? 1 : 0;
}

- (id <QLPreviewItem>)previewPanel:(QLPreviewPanel *)[[maybe_unused]]_panel
previewItemAtIndex:(NSInteger)index
{
    return index == 0 ? m_URL : nil;
}

- (void)setPreviewURL:(NSURL*)_url
{
    if( _url == m_URL )
        return;
    
    m_URL = _url;
    [QLPreviewPanel.sharedPreviewPanel reloadData];
}

- (BOOL)previewPanel:(QLPreviewPanel *)[[maybe_unused]]_panel handleEvent:(NSEvent *)event
{
    if( event.type == NSKeyDown ) {
        auto main_wnd = NSApp.mainWindow;
        if( main_wnd &&
            main_wnd.visible ) {
            [main_wnd.firstResponder keyDown:event];
            return true;
        }
    }
    return false;
}

@end

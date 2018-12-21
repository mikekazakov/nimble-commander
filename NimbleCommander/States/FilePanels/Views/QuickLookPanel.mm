// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "QuickLookPanel.h"
#include <Quartz/Quartz.h>
#include "../MainWindowFilePanelState.h"
#include "QuickLookVFSBridge.h"
#include <Habanero/dispatch_cpp.h>
#include <Utility/StringExtras.h>

static const std::chrono::nanoseconds g_Delay = std::chrono::milliseconds{100};

@class NCPanelQLPanelProxy;
static NCPanelQLPanelProxy *Proxy();

@interface NCPanelQLPanelProxy : NSObject<QLPreviewPanelDataSource, QLPreviewPanelDelegate>
@property (weak, nonatomic) MainWindowFilePanelState *target;
- (void)setPreviewURL:(NSURL*)_url;
@end

@implementation NCPanelQLPanelAdaptor
{
    std::string     m_CurrentPath;
    VFSHostWeakPtr  m_CurrentHost;
    std::atomic_ullong m_CurrentTicket;
}

- (instancetype)init
{
    if( self = [super init] ) {
        m_CurrentTicket = 0;
    }
    return self;
}

+ (NCPanelQLPanelAdaptor*)instance
{
    static NCPanelQLPanelAdaptor *inst = [[NCPanelQLPanelAdaptor alloc] init];
    return inst;
}

- (void)previewVFSItem:(const VFSPath&)_path forPanel:(PanelController*)_panel
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
        [Proxy() setPreviewURL:[NSURL fileURLWithPath:path]];
}

- (void)doVFSPreview:(const std::string&)_path
                host:(const VFSHostPtr&)_host
              ticket:(uint64_t)_ticket
{
    dispatch_after(g_Delay,
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                   [=]{
                       if( _ticket != m_CurrentTicket )
                           return;
                       
                       const auto url = nc::panel::QuickLookVFSBridge{}.FetchItem(_path, *_host);
                       
                       if( _ticket != m_CurrentTicket )
                           return;
                       
                       dispatch_to_main_queue([=]{
                           if( _ticket != m_CurrentTicket )
                               return;
                           [Proxy() setPreviewURL:url];
                       });
                   });
}

+ (NCPanelQLPanelAdaptor*) adaptorForState:(MainWindowFilePanelState*)_state
{
    if( !QLPreviewPanel.sharedPreviewPanelExists ||
        !QLPreviewPanel.sharedPreviewPanel.isVisible )
        return nil;
    
    if( Proxy().target != _state )
        return nil;
    
    return [NCPanelQLPanelAdaptor instance];
}

+ (void)registerQuickLook:(QLPreviewPanel *)_ql_panel forState:(MainWindowFilePanelState*)_state;
{
    auto p = Proxy();
    p.target = _state;
    _ql_panel.dataSource = p;
    _ql_panel.delegate = p;
}

+ (void)unregisterQuickLook:(QLPreviewPanel *)_ql_panel forState:(MainWindowFilePanelState*)_state;
{
    NCPanelQLPanelAdaptor.instance->m_CurrentPath = "";
    NCPanelQLPanelAdaptor.instance->m_CurrentHost.reset();
    
    auto p = Proxy();
    if( p.target == _state ) {
        p.target = nil;
        [p setPreviewURL:nil];
    }
}

@end

@implementation NCPanelQLPanelProxy
{
    NSURL *m_URL;
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel
{
    return m_URL ? 1 : 0;
}

- (id <QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index
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

- (BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event
{
    if( panel.inFullScreenMode )
        return false;

    if( event.type == NSKeyDown ) {
        if( MainWindowFilePanelState *state = self.target ) {
            [state.window.firstResponder keyDown:event];
            return true;
        }
    }
    
    return false;
}

@end

static NCPanelQLPanelProxy *Proxy()
{
    static NCPanelQLPanelProxy *inst = [[NCPanelQLPanelProxy alloc] init];
    return inst;
}

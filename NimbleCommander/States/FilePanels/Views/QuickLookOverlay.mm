// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Quartz/Quartz.h>
#include "QuickLookOverlay.h"
#include <Utility/SystemInformation.h>
#include "QuickLookVFSBridge.h"
#include <Habanero/dispatch_cpp.h>
#include <Utility/StringExtras.h>

static const std::chrono::nanoseconds g_Delay = std::chrono::milliseconds{100};

@interface NCPanelQLOverlayWrapper : QLPreviewView

- (void)previewItem:(const std::string&)_path at:(const VFSHostPtr&)_host;

@end

@implementation NCPanelQLOverlayWrapper
{
    std::string         m_CurrentPath;
    VFSHostWeakPtr      m_CurrentHost;
    std::atomic_bool    m_Closed;
    std::atomic_ullong  m_CurrentTicket;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect style:QLPreviewViewStyleNormal];
    if (self) {
        m_Closed = false;
        m_CurrentTicket = 0;
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
    [super viewDidMoveToSuperview];
    
    if(self.superview == nil)
        [self close];
}

- (void)previewItem:(const std::string&)_path at:(const VFSHostPtr&)_host
{
    dispatch_assert_main_queue();
    
    if( m_Closed )
        return;
    
    if( !_host || _path.empty() )
        return;
    
    if( _path == m_CurrentPath &&
        _host == m_CurrentHost.lock() )
        return;
    
    m_CurrentPath = _path;
    m_CurrentHost = _host;
    
    if( _host->IsNativeFS() )
        [self doNativeNative:_path];
    else
        [self doVFSPreview:_path host:_host ticket:m_CurrentTicket];
}

- (void) doNativeNative:(const std::string&)_path
{
    if( const auto path = [NSString stringWithUTF8StdString:_path] )
        self.previewItem = [NSURL fileURLWithPath:path];
}

- (void)doVFSPreview:(const std::string&)_path
                host:(const VFSHostPtr&)_host
              ticket:(uint64_t)_ticket
{
    std::string path = _path;
    VFSHostPtr host = _host;
    dispatch_after(g_Delay,
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                   [=]{
                       if( _ticket != m_CurrentTicket || m_Closed )
                           return;

                       const auto url = nc::panel::QuickLookVFSBridge{}.FetchItem(path, *host);
                       
                       if( _ticket != m_CurrentTicket || m_Closed )
                           return;

                       dispatch_to_main_queue([=]{
                           if( _ticket != m_CurrentTicket || m_Closed )
                               return;
                           self.previewItem = url;
                       });
                   });
}

- (void)frameDidChange
{
    if( nc::utility::GetOSXVersion() < nc::utility::OSXVersion::OSX_13 ) {
        NSView *subview = self.subviews[0];
        [subview setFrameSize:self.frame.size];
    }
}

@end

@implementation NCPanelQLOverlay
{
    NCPanelQLOverlayWrapper *m_QL;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        m_QL = [[NCPanelQLOverlayWrapper alloc] initWithFrame:self.frame];
        m_QL.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_QL];

        NSDictionary *views = NSDictionaryOfVariableBindings(m_QL);
        [self addConstraints:
            [NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_QL]-(==0)-|"
                                                    options:0
                                                    metrics:nil
                                                      views:views]];
        [self addConstraints:
            [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_QL]-(==0)-|"
                                                    options:0
                                                    metrics:nil
                                                      views:views]];
    }
    return self;
}

- (void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)previewVFSItem:(const VFSPath&)_path forPanel:(PanelController*)_panel
{
    if( !_path )
        return;
    
    [m_QL previewItem:_path.Path() at:_path.Host()];
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
    if( self.window.isKeyWindow ) {
        [NSColor.windowBackgroundColor set];
        NSRectFill(dirtyRect);
    }
    else {
        NSDrawWindowBackground(dirtyRect);
    }
}

- (void)viewWillMoveToWindow:(NSWindow *)_wnd
{
    [super viewWillMoveToWindow:_wnd];
    
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

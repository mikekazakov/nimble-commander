// Copyright (C) 2013-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "QuickLookOverlay.h"
#include <Quartz/Quartz.h>
#include <Utility/SystemInformation.h>
#include <Base/dispatch_cpp.h>
#include <Utility/StringExtras.h>
#include <Utility/ExtensionLowercaseComparison.h>
#include <Utility/PathManip.h>
#include "QuickLookVFSBridge.h"
#include <filesystem>

static const std::chrono::nanoseconds g_Delay = std::chrono::milliseconds{100};
static const auto g_HazardousExtensionsList = "filePanel.presentation.quickLookHazardousExtensionsList";

// static NSImage *CaptureViewHierarcy(NSView *_view)
//{
//    if( _view.superview == nil )
//        return nil;
//    NSWindow *window = _view.window;
//    if( window == nil )
//        return nil;
//    NSScreen *screen = window.screen;
//    if( screen == nil )
//        return nil;
//
//    auto wnd_rc = [_view convertRect:_view.bounds toView:nil];
//    auto scr_rc = [_view.window convertRectToScreen:wnd_rc];
//    scr_rc.origin.y = screen.frame.size.height - scr_rc.origin.y - scr_rc.size.height;
//    auto win_num = static_cast<CGWindowID>(_view.window.windowNumber);
//    CGImageRef img =  CGWindowListCreateImage(scr_rc,
//                                       kCGWindowListOptionIncludingWindow,
//                                       win_num,
//                                       0);
//    NSImage *ns_img = [[NSImage alloc] initWithCGImage:img size:NSZeroSize];
//    return ns_img;
//};

@interface NCPanelQLOverlayWrapper : QLPreviewView

- (void)previewItem:(const std::filesystem::path &)_path at:(const VFSHostPtr &)_host;

@end

@implementation NCPanelQLOverlayWrapper {
    std::string m_CurrentPath;
    VFSHostWeakPtr m_CurrentHost;
    std::atomic_bool m_Closed;
    std::atomic_ullong m_CurrentTicket;
    nc::panel::QuickLookVFSBridge *m_Bridge;
    // It's a workaround for the macOS bug reported in FB9809109/FB5352643.
    bool m_Hazard;
    std::optional<nc::utility::ExtensionsLowercaseList> m_HazardousExtsList;
}

- (id)initWithFrame:(NSRect)frameRect
             bridge:(nc::panel::QuickLookVFSBridge &)_vfs_bridge
             config:(nc::config::Config &)_config
{
    self = [super initWithFrame:frameRect style:QLPreviewViewStyleNormal];
    if( self ) {
        m_Bridge = &_vfs_bridge;
        m_Closed = false;
        m_Hazard = false;
        m_CurrentTicket = 0;
        self.shouldCloseWithWindow = false;

        auto hazard_list = _config.GetString(g_HazardousExtensionsList);
        if( hazard_list != "*" ) {
            m_HazardousExtsList.emplace(hazard_list);
        }
    }
    return self;
}

- (BOOL)acceptsFirstResponder
{
    return false;
}

- (void)close
{
    [super close];
    m_Closed = true;
}

- (void)viewDidMoveToSuperview
{
    [super viewDidMoveToSuperview];

    if( self.superview == nil )
        [self close];
}

- (void)previewItem:(const std::filesystem::path &)_path at:(const VFSHostPtr &)_host
{
    dispatch_assert_main_queue();

    if( m_Closed )
        return;

    if( !_host || _path.empty() )
        return;

    if( _path == m_CurrentPath && _host == m_CurrentHost.lock() )
        return;

    if( m_Hazard ) {
        self.previewItem = nil;
        m_Hazard = false;
    }

    m_CurrentPath = _path;
    m_CurrentHost = _host;

    if( _host->IsNativeFS() )
        [self doNativeNative:_path];
    else
        [self doVFSPreview:_path host:_host ticket:m_CurrentTicket];
}

- (void)doNativeNative:(const std::filesystem::path &)_path
{
    if( const auto path = [NSString stringWithUTF8StdString:_path] ) {
        self.previewItem = [NSURL fileURLWithPath:path];
        if( [self isHazardousPath:_path] ) {
            m_Hazard = true;
        }
    }
}

- (void)doVFSPreview:(const std::filesystem::path &)_path host:(const VFSHostPtr &)_host ticket:(uint64_t)_ticket
{
    const std::filesystem::path &path = _path;
    const VFSHostPtr &host = _host;
    dispatch_after(g_Delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), [=] {
        if( _ticket != m_CurrentTicket || m_Closed )
            return;

        const auto url = m_Bridge->FetchItem(path, *host);

        if( _ticket != m_CurrentTicket || m_Closed )
            return;

        dispatch_to_main_queue([=] {
            if( _ticket != m_CurrentTicket || m_Closed )
                return;
            self.previewItem = url;
            if( [self isHazardousPath:path] )
                m_Hazard = true;
        });
    });
}

- (bool)isHazardousPath:(const std::filesystem::path &)_path
{
    if( m_HazardousExtsList == std::nullopt )
        return true;
    return m_HazardousExtsList->contains(nc::utility::PathManip::Extension(_path.native()));
}

@end

@implementation NCPanelQLOverlay {
    NCPanelQLOverlayWrapper *m_QL;
    nc::panel::QuickLookVFSBridge *m_Bridge;
    nc::config::Config *m_Config;
}

- (instancetype)initWithFrame:(NSRect)frameRect
                       bridge:(nc::panel::QuickLookVFSBridge &)_vfs_bridge
                       config:(nc::config::Config &)_config
{
    self = [super initWithFrame:frameRect];
    if( self ) {
        m_Bridge = &_vfs_bridge;
        m_Config = &_config;
        [self createQLView];
    }
    return self;
}

- (id)initWithFrame:(NSRect) [[maybe_unused]] _frame_rect
{
    assert(0);
    return nil;
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)createQLView
{
    if( m_QL ) {
        [m_QL removeFromSuperviewWithoutNeedingDisplay];
        m_QL = nil;
    }

    auto ql = [[NCPanelQLOverlayWrapper alloc] initWithFrame:self.frame bridge:*m_Bridge config:*m_Config];
    ql.translatesAutoresizingMaskIntoConstraints = false;
    [self addSubview:ql];

    NSDictionary *views = NSDictionaryOfVariableBindings(ql);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[ql]-(==0)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[ql]-(==0)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];

    m_QL = ql;
}

- (void)previewVFSItem:(const nc::vfs::VFSPath &)_path forPanel:(PanelController *) [[maybe_unused]] _panel
{
    if( !_path )
        return;
    [m_QL previewItem:_path.Path() at:_path.Host()];
}

- (BOOL)acceptsFirstResponder
{
    return false;
}

- (BOOL)isOpaque
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

    if( !_wnd )
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

- (void)windowKeyChanged
{
    self.needsDisplay = true;
}

@end

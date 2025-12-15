// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelGalleryCentralView.h"
#include <Utility/UTI.h>
#include <Utility/ExtensionLowercaseComparison.h>
#include <Utility/StringExtras.h>
#include <Utility/PathManip.h>
#include <Base/dispatch_cpp.h>
#include <Base/mach_time.h>
#include <Quartz/Quartz.h>

static const std::chrono::nanoseconds g_DebounceDelay = std::chrono::milliseconds{16};

@implementation NCPanelGalleryCentralView {
    const nc::utility::UTIDB *m_UTIDB;
    QLPreviewView *m_QLView;
    NSImageView *m_FallbackImageView;
    std::atomic_ullong m_CurrentTicket;

    std::filesystem::path m_CurrentPath;
    VFSHostWeakPtr m_CurrentHost;

    // It's a workaround for the macOS bug reported in FB9809109/FB5352643.
    bool m_CurrentPreviewIsHazardous;
    std::optional<nc::utility::ExtensionsLowercaseList> m_HazardousExtsList; // empty means everything is hazardous
}

- (instancetype)initWithFrame:(NSRect)_frame
                        UTIDB:(const nc::utility::UTIDB &)_UTIDB
    QLHazardousExtensionsList:(const std::string &)_ql_hazard_list
{
    dispatch_assert_main_queue();
    self = [super initWithFrame:_frame];
    if( !self )
        return nil;
    m_UTIDB = &_UTIDB;
    m_CurrentPreviewIsHazardous = false;
    m_CurrentTicket = 0;

    self.translatesAutoresizingMaskIntoConstraints = false;

    m_QLView = [[QLPreviewView alloc] initWithFrame:_frame style:QLPreviewViewStyleNormal];
    m_QLView.translatesAutoresizingMaskIntoConstraints = false;
    [self addSubview:m_QLView];

    m_FallbackImageView = [[NSImageView alloc] initWithFrame:_frame];
    m_FallbackImageView.translatesAutoresizingMaskIntoConstraints = false;
    m_FallbackImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    m_FallbackImageView.hidden = true;
    [self addSubview:m_FallbackImageView];

    const auto views_dict = NSDictionaryOfVariableBindings(m_QLView, m_FallbackImageView);
    const auto add_constraints = [&](NSString *_vis_fmt) {
        const auto constraints = [NSLayoutConstraint constraintsWithVisualFormat:_vis_fmt
                                                                         options:0
                                                                         metrics:nil
                                                                           views:views_dict];
        [self addConstraints:constraints];
    };
    add_constraints(@"|-(0)-[m_QLView]-(0)-|");
    add_constraints(@"|-(0)-[m_FallbackImageView]-(0)-|");
    add_constraints(@"V:|-(0)-[m_QLView]-(0)-|");
    add_constraints(@"V:|-(0)-[m_FallbackImageView]-(0)-|");

    if( _ql_hazard_list != "*" ) {
        m_HazardousExtsList.emplace(_ql_hazard_list);
    }

    return self;
}

- (void)showVFSItem:(VFSListingItem)_item
{
    dispatch_assert_main_queue();
    if( !_item )
        return; // ignore bogus requests. TODO: reset the view here?

    if( m_CurrentPath == _item.Path() && m_CurrentHost.lock() == _item.Host() )
        return; // nothing to do - redundant request

    const bool is_native_vfs = _item.Host()->IsNativeFS();
    const bool potentially_ql = [self couldBeSupportedByQuickLook:_item];

    // Regardless of the following logic, a new request means cancelling any previous ones
    ++m_CurrentTicket;

    // Update our state to represent this item
    m_CurrentHost = _item.Host();
    m_CurrentPath = _item.Path();

    if( is_native_vfs && potentially_ql ) {
        // Dispatch this request to QL right away, let it deal with it asynchronously
        [self previewNativeQL:_item];
        return;
    }

    if( is_native_vfs && !potentially_ql ) {
        [self previewNativeIcon:_item ticket:m_CurrentTicket];
    }
}

- (void)previewNativeQL:(const VFSListingItem &)_item
{
    dispatch_assert_main_queue();
    assert(_item);
    const std::string path = _item.Path();
    if( NSString *ns_path = [NSString stringWithUTF8StdString:path] ) {
        if( NSURL *url = [NSURL fileURLWithPath:ns_path] ) {
            [self ensureQLVisible];
            if( m_CurrentPreviewIsHazardous )
                m_QLView.previewItem = nil; // to prevent an ObjC exception from inside QL - reset the view first
            m_QLView.previewItem = url;
            m_CurrentPreviewIsHazardous = [self isHazardousPath:path];
        }
    }
}

- (void)previewNativeIcon:(const VFSListingItem &)_item ticket:(uint64_t)_ticket
{
    dispatch_assert_main_queue();
    assert(_item);

    const NSRect bounds = self.bounds;

    __weak NCPanelGalleryCentralView *const weak_self = self;
    const std::string path = _item.Path();
    auto worker = [weak_self, path, _ticket, bounds] {
        dispatch_assert_background_queue();
        if( NCPanelGalleryCentralView *const strong_self = weak_self;
            strong_self == nil || _ticket != strong_self->m_CurrentTicket )
            return; // Expired request

        NSString *const ns_path = [NSString stringWithUTF8StdString:path];
        if( ns_path == nil )
            return;

        // Produce the icon. It can be a (very) lazy NSImage, which is completely opaque and system-dependent.
        NSImage *const image = [[NSWorkspace sharedWorkspace] iconForFile:ns_path];

        if( NCPanelGalleryCentralView *const strong_self = weak_self;
            strong_self == nil || _ticket != strong_self->m_CurrentTicket )
            return; // Expired request

        // Force image rendering at ~ desired size, here at the background, instead of the main thread.
        // This avoids (or at least reduces) stuttering when the image is finally assigned to the image view.
        // The result of this operation is purposely discarded.
        // TODO: how to handle pixel scaling here?
        NSRect tmp_bounds = bounds;
        [image CGImageForProposedRect:&tmp_bounds context:nil hints:nil];

        dispatch_to_main_queue([weak_self, image, _ticket] {
            if( NCPanelGalleryCentralView *const strong_self = weak_self ) {
                [strong_self commitPreviewedIcon:image ticket:_ticket];
            }
        });
    };

    // Debounce expensive requests by delaying them slightly + relying on ticketing that discards previous requests.
    dispatch_after(g_DebounceDelay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), worker);
}

- (void)commitPreviewedIcon:(NSImage *)_image ticket:(uint64_t)_ticket
{
    dispatch_assert_main_queue();
    if( _ticket != m_CurrentTicket )
        return; // Expired request
    [self ensureFallbackVisible];
    m_FallbackImageView.image = _image;
}

- (void)ensureQLVisible
{
    dispatch_assert_main_queue();
    m_QLView.hidden = false;
    m_FallbackImageView.hidden = true;
}

- (void)ensureFallbackVisible
{
    dispatch_assert_main_queue();
    m_QLView.hidden = true;
    m_QLView.previewItem = nil; // NB! Without resetting the preview to nil, it somehow manages to completely freeze
    m_FallbackImageView.hidden = false;
}

- (bool)couldBeSupportedByQuickLook:(const VFSListingItem &)_item
{
    if( !_item.HasExtension() ) {
        // No extensions -> no UTI mapping -> no QL generator / preview appex / thumbnail appex can support it
        return false;
    }

    const std::string_view extension = _item.Extension();
    if( extension == "app" ) {
        return false; // QL cannot preview .app bundles, leave it to NSWorkspace
    }

    // Anything permanently registered in the system can be theoretically supported by QL
    const std::string uti = m_UTIDB->UTIForExtension(extension);
    return m_UTIDB->IsDeclaredUTI(uti);
}

- (bool)isHazardousPath:(std::string_view)_path
{
    if( m_HazardousExtsList == std::nullopt )
        return true;
    return m_HazardousExtsList->contains(nc::utility::PathManip::Extension(_path));
}

@end
